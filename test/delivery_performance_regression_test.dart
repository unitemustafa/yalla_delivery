import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/constants/app_assets.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/core/network/api_exception.dart';
import 'package:yalla_home/core/presentation/widgets/authenticated_network_image.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_repository_impl.dart';
import 'package:yalla_home/features/deliveries/data/courier_profile_api.dart';
import 'package:yalla_home/features/deliveries/domain/courier_account.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notification.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notification_page.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notifications_repository.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notifications_use_cases.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order_page.dart';
import 'package:yalla_home/features/deliveries/domain/courier_orders_use_cases.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_notifications_controller.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_orders_cubit.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_profile_controller.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_notifications_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_orders_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/order_details_view.dart';

CourierOrder _order(int id, {int products = 0, bool manyMarkets = false}) =>
    CourierOrder.fromJson({
      'id': id,
      'status': 'assigned',
      'created_at': '2030-01-01T00:00:00Z',
      'items': List.generate(
        products,
        (i) => {
          'product_name': 'Product $i',
          'quantity': 1,
          'unit_price': '10',
          if (manyMarkets) 'market_id': i + 1,
          if (manyMarkets) 'market_name': 'Market $i',
        },
      ),
    });
CourierOrdersCubit _orders(_Orders api) {
  final repo = CourierOrdersRepositoryImpl(api);
  return CourierOrdersCubit(
    LoadActiveCourierOrders(repo),
    LoadCourierHistory(repo),
  );
}

CourierNotificationsController _notifications(_Notifications repo) =>
    CourierNotificationsController(
      useCases: CourierNotificationsUseCases(repo),
    );
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'active summary uses full totals and does not invent missing server counts',
    (tester) async {
      Widget screen(int? pickup) => _app(
        CourierOrdersView(
          orders: List.generate(30, _order),
          totals: CourierOrderTotals(
            count: 300,
            value: 3000,
            deliveryFees: 300,
            pickupRequiredCount: pickup,
          ),
          onPickedUp: (_) async => _order(1),
          onDelivered: (_, _) async => _order(1),
          onRefresh: () async {},
          unreadNotificationCount: 0,
          onNotificationsPressed: () {},
        ),
      );
      await tester.pumpWidget(screen(120));
      expect(find.text('300'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      await tester.pumpWidget(screen(null));
      expect(find.text('—'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'delivery before loading more cannot skip a shifted active-page boundary',
    () async {
      final api = _Orders();
      final cubit = _orders(api);
      addTearDown(cubit.close);
      await cubit.refreshActive();
      cubit.replaceOrder(
        _order(1).copyWith(
          status: CourierOrderStatus.delivered,
          rawStatus: 'delivered',
        ),
      );
      api.firstId = 2;
      await cubit.loadMoreActive();
      expect(api.pages, [1, 1, 2]);
      expect(
        cubit.state.active.map((order) => order.id),
        List.generate(60, (i) => '${i + 2}'),
      );
    },
  );
  test(
    'closing orders cancels queued revalidation after the outstanding response',
    () async {
      final api = _Orders()..pending = Completer<CourierOrderPage>();
      final cubit = _orders(api);
      final loading = cubit.refreshActive();
      final push = cubit.refreshActive(invalidated: true);
      await cubit.close();
      api.pending!.complete(_Orders.page(1));
      await Future.wait([loading, push]);
      expect(api.pages, [1]);
      expect(cubit.state.active, isEmpty);
    },
  );
  test(
    'a late mark-read response cannot open content from a cleared session',
    () async {
      final repo = _Notifications();
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      await controller.loadNotifications();
      final item = controller.notifications.first;
      repo.readPending = Completer<ApiResult<CourierNotification>>();
      final marking = controller.markRead(item);
      await Future<void>.delayed(Duration.zero);
      controller.clear();
      final rejected = expectLater(
        marking,
        throwsA(isA<CourierNotificationActionException>()),
      );
      repo.readPending!.complete(ApiSuccess(item.copyWith(isRead: true)));
      await rejected;
      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount, 0);
    },
  );
  test(
    'active first page is available without downloading all orders; retry keeps cursor',
    () async {
      final api = _Orders();
      final cubit = _orders(api);
      addTearDown(cubit.close);
      await cubit.refreshActive();
      expect(api.pages, [1]);
      expect(cubit.state.active.length, 30);
      expect(cubit.state.activeTotals!.count, 300);
      expect(cubit.state.hasNextActive, isTrue);
      api.fail = true;
      await cubit.loadMoreActive();
      expect(cubit.state.active.length, 30);
      expect(cubit.state.activeMoreError, 'offline');
      // A history update must not erase the active-page error.
      await cubit.refreshHistory();
      expect(cubit.state.activeMoreError, 'offline');
      api.fail = false;
      await Future.wait([cubit.loadMoreActive(), cubit.loadMoreActive()]);
      expect(api.pages, [1, 2, 2]);
      expect(cubit.state.active.length, 60);
      expect(cubit.state.activeMoreError, isNull);
      await cubit.refreshActive();
      expect(cubit.state.active.length, 60);
    },
  );
  test(
    'push invalidations during loading drain one fresh request and all callers wait',
    () async {
      final api = _Orders()..pending = Completer<CourierOrderPage>();
      final cubit = _orders(api);
      addTearDown(cubit.close);
      final initial = cubit.refreshActive();
      final push = cubit.refreshActive(invalidated: true);
      final secondPush = cubit.refreshActive(invalidated: true);
      api.pending!.complete(_Orders.page(1, firstId: 999));
      api.pending = null;
      await Future.wait([initial, push, secondPush]);
      expect(api.pages, [1, 1]);
      expect(cubit.state.active.first.id, '1');
      expect(cubit.state.loading, isFalse);
    },
  );
  test(
    'an order action during loading cannot be overwritten by its stale snapshot',
    () async {
      final api = _Orders();
      final cubit = _orders(api);
      addTearDown(cubit.close);
      await cubit.refreshActive();
      api.pending = Completer<CourierOrderPage>();
      final loading = cubit.refreshActive();
      cubit.replaceOrder(
        _order(1).copyWith(
          status: CourierOrderStatus.delivered,
          rawStatus: 'delivered',
        ),
      );
      expect(cubit.state.activeTotals!.count, 299);
      api.pending!.complete(_Orders.page(1));
      api.pending = null;
      api.firstId = 2;
      await loading;
      expect(cubit.state.active.first.id, '2');
      expect(cubit.state.loading, isFalse);
    },
  );
  test(
    'notification membership changes preserve global unread count and page boundary',
    () async {
      final repo = _Notifications();
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      await controller.loadNotifications();
      expect(controller.notifications.length, 30);
      expect(controller.totalCount, 100);
      expect(controller.unreadCount, 100);
      final first = controller.notifications.first;
      await controller.markRead(first);
      await controller.markRead(first);
      expect(controller.unreadCount, 99);
      expect(repo.readCalls, 1);
      await controller.deleteNotification(controller.notifications.first);
      expect(controller.unreadCount, 99);
      await Future.wait([controller.loadMore(), controller.loadMore()]);
      expect(repo.pages, [1, 1, 2]);
      expect(
        controller.notifications.map((i) => i.id),
        List.generate(60, (i) => '${i + 2}'),
      );
      expect(controller.totalCount, 99);
    },
  );
  test(
    'notification extra-page failure retries without discarding loaded rows',
    () async {
      final repo = _Notifications();
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      await controller.loadNotifications();
      repo.fail = true;
      await controller.loadMore();
      expect(controller.moreError, 'offline');
      expect(controller.notifications.length, 30);
      repo.fail = false;
      await controller.loadMore();
      expect(repo.pages, [1, 2, 2]);
      expect(controller.notifications.length, 60);
      expect(controller.moreError, isNull);
    },
  );
  test(
    'clear detaches an old notification load from the next session',
    () async {
      final repo = _Notifications()
        ..pending = Completer<ApiResult<CourierNotificationPage>>();
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      final old = controller.loadNotifications();
      final pending = repo.pending!;
      controller.clear();
      repo.pending = null;
      repo.items = repo.items.skip(50).toList();
      await controller.loadNotifications();
      expect(controller.notifications.first.id, '51');
      pending.complete(
        ApiSuccess(
          CourierNotificationPage(
            items: const [],
            count: 0,
            unreadCount: 0,
            hasNext: false,
          ),
        ),
      );
      await old;
      expect(controller.notifications.first.id, '51');
      expect(controller.unreadCount, 50);
    },
  );
  test('dispose ignores late notification and profile responses', () async {
    final repo = _Notifications()
      ..pending = Completer<ApiResult<CourierNotificationPage>>();
    final controller = _notifications(repo);
    final load = controller.loadNotifications();
    controller.dispose();
    repo.pending!.complete(
      const ApiSuccess(
        CourierNotificationPage(
          items: [],
          count: 0,
          unreadCount: 0,
          hasNext: false,
        ),
      ),
    );
    await load;
    await controller.loadMore();
    expect(repo.pages, [1]);
    final api = _Profile();
    final profile = CourierProfileController(api: api);
    final profileLoad = profile.loadAccount();
    profile.dispose();
    api.pending.complete(CourierAccount.fromJson({'id': 1}));
    await profileLoad;
    expect(profile.account, isNull);
  });
  test(
    'a late mark-all response cannot mutate a cleared notification session',
    () async {
      final repo = _Notifications();
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      await controller.loadNotifications();
      repo.readAllPending = Completer<ApiResult<int>>();
      final marking = controller.markAllRead();
      await Future<void>.delayed(Duration.zero);
      controller.clear();
      repo.readAllPending!.complete(const ApiSuccess(100));
      await marking;
      expect(controller.notifications, isEmpty);
      expect(controller.totalCount, 0);
      expect(controller.isMarkingAllRead, isFalse);
    },
  );
  testWidgets(
    '300 notifications mount only visible cards and the last remains reachable',
    (tester) async {
      final repo = _Notifications(count: 300)..pageSize = 300;
      final controller = _notifications(repo);
      addTearDown(controller.dispose);
      await controller.loadNotifications();
      await tester.pumpWidget(
        _app(
          CourierNotificationsView(
            controller: controller,
            onOrderTap: (_) {},
            onUnreadCountChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rows = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_NotificationCard',
      );
      expect(rows.evaluate().length, inInclusiveRange(1, 20));
      await tester.scrollUntilVisible(
        find.text('Notification 300'),
        500,
        maxScrolls: 150,
      );
      expect(find.text('Notification 300'), findsOneWidget);
      expect(rows.evaluate().length, lessThan(20));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final manyMarkets in [false, true]) {
    testWidgets(
      '300 products remain lazy across ${manyMarkets ? 300 : 1} market groups',
      (tester) async {
        final data = _order(1, products: 300, manyMarkets: manyMarkets);
        await tester.pumpWidget(
          _app(OrderDetailsView(order: data, loadOrder: (_) async => data)),
        );
        await tester.pumpAndSettle();
        final rows = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ProductRow',
        );
        expect(rows.evaluate().length, lessThan(20));
        await tester.scrollUntilVisible(
          find.text('Product 299'),
          600,
          maxScrolls: 200,
        );
        expect(find.text('Product 299'), findsOneWidget);
        expect(rows.evaluate().length, lessThan(20));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('private image decode is bounded by physical layout dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await rootBundle.load(
      AppAssets.defaultProduct,
    )).buffer.asUint8List();
    await tester.pumpWidget(
      _app(
        Center(
          child: AuthenticatedNetworkImage(
            url: 'https://fixture.invalid/private',
            placeholderAsset: AppAssets.defaultProduct,
            width: 320,
            height: 210,
            loader: (_) async => bytes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final provider =
        tester.widget<Image>(find.byType(Image).first).image as ResizeImage;
    expect(provider.width, 640);
    expect(provider.height, 420);
    expect(provider.policy, ResizeImagePolicy.fit);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Orders extends CourierOrdersApi {
  final pages = <int>[];
  Completer<CourierOrderPage>? pending;
  bool fail = false;
  int firstId = 1;
  static CourierOrderPage page(int page, {int firstId = 1}) => CourierOrderPage(
    orders: List.generate(30, (i) => _order(firstId + (page - 1) * 30 + i)),
    hasNext: page < 10,
    totals: const CourierOrderTotals(
      count: 300,
      value: 3000,
      deliveryFees: 300,
      pickupRequiredCount: 300,
    ),
  );
  @override
  Future<CourierOrderPage> loadActivePage({int page = 1}) async {
    pages.add(page);
    if (pending != null) return pending!.future;
    if (fail) throw const ApiException('offline');
    return _Orders.page(page, firstId: firstId);
  }

  @override
  Future<CourierOrderPage> loadHistoryPage({
    int page = 1,
    DateTime? from,
    DateTime? before,
  }) async => const CourierOrderPage(
    orders: [],
    hasNext: false,
    totals: CourierOrderTotals(count: 0, value: 0, deliveryFees: 0),
  );
}

class _Notifications implements CourierNotificationsRepository {
  _Notifications({int count = 100})
    : items = List.generate(
        count,
        (i) => CourierNotification.fromJson({
          'id': i + 1,
          'title': 'Notification ${i + 1}',
          'type': 'fixture',
          'message': 'Fixture',
          'created_at': '2030-01-01T00:00:00Z',
          'is_read': false,
        }),
      );
  List<CourierNotification> items;
  final pages = <int>[];
  int pageSize = 30, readCalls = 0;
  bool fail = false;
  Completer<ApiResult<CourierNotificationPage>>? pending;
  Completer<ApiResult<int>>? readAllPending;
  Completer<ApiResult<CourierNotification>>? readPending;
  @override
  Future<ApiResult<CourierNotificationPage>> loadPage({int page = 1}) async {
    pages.add(page);
    if (pending != null) return pending!.future;
    if (fail) {
      return const ApiFailure(ApiFailureReason.network, message: 'offline');
    }
    return ApiSuccess(
      CourierNotificationPage(
        items: items.skip((page - 1) * pageSize).take(pageSize).toList(),
        count: items.length,
        unreadCount: items.where((i) => !i.isRead).length,
        hasNext: page * pageSize < items.length,
      ),
    );
  }

  @override
  Future<ApiResult<int>> unreadCount() async =>
      ApiSuccess(items.where((i) => !i.isRead).length);
  @override
  Future<ApiResult<CourierNotification>> markRead(
    CourierNotification item,
  ) async {
    if (readPending != null) return readPending!.future;
    readCalls++;
    final updated = item.copyWith(isRead: true);
    items = [
      for (final i in items)
        if (i.id == item.id) updated else i,
    ];
    return ApiSuccess(updated);
  }

  @override
  Future<ApiResult<int>> markAllRead() async =>
      readAllPending?.future ?? const ApiSuccess(0);
  @override
  Future<ApiResult<void>> delete(String id) async {
    items.removeWhere((i) => i.id == id);
    return const ApiSuccess(null);
  }
}

class _Profile extends CourierProfileApi {
  final pending = Completer<CourierAccount>();
  @override
  Future<CourierAccount> loadAccount() => pending.future;
}
