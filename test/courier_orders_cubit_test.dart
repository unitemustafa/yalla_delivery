import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/network/api_exception.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_repository_impl.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order_page.dart';
import 'package:yalla_home/features/deliveries/domain/courier_orders_use_cases.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_orders_cubit.dart';

class _Api extends CourierOrdersApi {
  final pages = <int>[];
  final ranges = <DateTime?>[];
  bool failNextPage = false;
  Completer<CourierOrderPage>? pending;
  @override
  Future<CourierOrderPage> loadHistoryPage({
    int page = 1,
    DateTime? from,
    DateTime? before,
  }) async {
    pages.add(page);
    ranges.add(from);
    if (pending != null) return pending!.future;
    if (page == 2 && failNextPage) throw const ApiException('offline');
    return CourierOrderPage(
      orders: [
        CourierOrder.fromJson({
          'id': page,
          'status': 'delivered',
          'created_at': '2030-01-01T00:00:00Z',
        }),
      ],
      hasNext: page == 1,
      totals: const CourierOrderTotals(count: 2, value: 20, deliveryFees: 2),
    );
  }
}

CourierOrdersCubit _cubit(_Api api) {
  final repo = CourierOrdersRepositoryImpl(api);
  return CourierOrdersCubit(
    LoadActiveCourierOrders(repo),
    LoadCourierHistory(repo),
  );
}

void main() {
  test('history refresh preserves already loaded pages', () async {
    final api = _Api();
    final cubit = _cubit(api);
    addTearDown(cubit.close);
    await cubit.refreshHistory();
    await cubit.loadMoreHistory();
    await cubit.refreshHistory();
    expect(api.pages, [1, 2, 1, 2]);
    expect(cubit.state.history.map((order) => order.id), ['1', '2']);
  });
  test(
    'history invalidation while loading revalidates the most recent range',
    () async {
      final api = _Api()..pending = Completer<CourierOrderPage>();
      final cubit = _cubit(api);
      addTearDown(cubit.close);
      final firstRange = DateTime.utc(2030);
      final nextRange = DateTime.utc(2030, 2);
      final initial = cubit.refreshHistory(from: firstRange);
      final updated = cubit.refreshHistory(from: nextRange);
      api.pending!.complete(
        const CourierOrderPage(
          orders: [],
          hasNext: false,
          totals: CourierOrderTotals(count: 0, value: 0, deliveryFees: 0),
        ),
      );
      api.pending = null;
      await Future.wait([initial, updated]);
      expect(api.ranges, [firstRange, nextRange]);
      expect(cubit.state.history.single.id, '1');
      expect(cubit.state.loadingHistory, isFalse);
    },
  );
  test(
    'history appends next page while aggregates remain server totals',
    () async {
      final api = _Api();
      final cubit = _cubit(api);
      addTearDown(cubit.close);
      await cubit.refreshHistory();
      expect(cubit.state.history, hasLength(1));
      expect(cubit.state.totals!.count, 2);
      await cubit.loadMoreHistory();
      expect(cubit.state.history.map((order) => order.id), ['1', '2']);
      expect(cubit.state.totals!.count, 2);
      expect(cubit.state.hasNext, isFalse);
      expect(api.pages, [1, 2]);
    },
  );

  test(
    'next page failure preserves loaded history and retries the same page',
    () async {
      final api = _Api()..failNextPage = true;
      final cubit = _cubit(api);
      addTearDown(cubit.close);
      await cubit.refreshHistory();
      await cubit.loadMoreHistory();
      expect(cubit.state.history.single.id, '1');
      expect(cubit.state.historyError, 'offline');
      api.failNextPage = false;
      await cubit.loadMoreHistory();
      expect(api.pages, [1, 2, 2]);
      expect(cubit.state.history, hasLength(2));
      expect(cubit.state.historyError, isNull);
    },
  );

  test('closed screen ignores an outstanding history response', () async {
    final api = _Api()..pending = Completer<CourierOrderPage>();
    final cubit = _cubit(api);
    final load = cubit.refreshHistory();
    await cubit.close();
    api.pending!.complete(
      const CourierOrderPage(
        orders: [],
        hasNext: false,
        totals: CourierOrderTotals(count: 0, value: 0, deliveryFees: 0),
      ),
    );
    await load;
    expect(cubit.isClosed, isTrue);
  });
}
