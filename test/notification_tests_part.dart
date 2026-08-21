part of 'widget_test.dart';

void _registerNotificationTests() {
  testWidgets('notification badge shows count and hides at zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsButton(unreadCount: 5, onPressed: () {}),
      ),
    );

    expect(find.text('5'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsButton(unreadCount: 0, onPressed: () {}),
      ),
    );

    expect(find.text('5'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  test('parses real notification responses safely', () {
    final raw = {
      'id': 91,
      'audience': 'courier',
      'type': 'order_assigned',
      'title': 'New order assigned',
      'message': 'A new order #123 has been assigned to you.',
      'order_id': 123,
      'is_read': false,
      'is_blocking': false,
      'is_resolved': false,
      'read_at': null,
      'resolved_at': null,
      'created_at': '2026-07-08T09:15:00Z',
    };

    final notification = CourierNotification.fromJson(raw);

    expect(notification.id, '91');
    expect(notification.orderId, '123');
    expect(notification.hasLinkedOrder, isTrue);
    expect(notification.isRead, isFalse);
    expect(notification.displayTitle, 'تم إسناد طلب جديد');
    expect(notification.displayMessage, 'تم إسناد الطلب #123 إليك.');
    expect(
      notification.createdAt,
      DateTime.parse('2026-07-08T09:15:00Z').toLocal(),
    );
  });

  test('parses raw-list and paginated notification responses', () {
    final raw = [
      _notificationJson(id: 1, orderId: 101),
      _notificationJson(id: 2, orderId: null, isRead: true),
    ];
    final paginated = {'count': 2, 'results': raw};

    expect(
      CourierNotificationsApi.parseNotificationsResponse(raw),
      hasLength(2),
    );
    expect(
      CourierNotificationsApi.parseNotificationsResponse(
        paginated,
      ).map((notification) => notification.id),
      ['1', '2'],
    );
  });

  test('parses backend unread count response', () {
    expect(
      CourierNotificationsApi.parseUnreadCountResponse({'unread_count': 7}),
      7,
    );
    expect(CourierNotificationsApi.parseUnreadCountResponse('4'), 4);
  });

  test(
    'controller updates unread badge only after mark-read success',
    () async {
      final api = _FakeNotificationsApi(
        notifications: [_notification(id: '1', orderId: '123')],
        unreadCount: 1,
      );
      final controller = CourierNotificationsController(api: api);
      await controller.loadNotifications();

      expect(controller.unreadCount, 1);
      await controller.markRead(controller.notifications.single);

      expect(api.markReadCalls, ['1']);
      expect(controller.notifications.single.isRead, isTrue);
      expect(controller.unreadCount, 0);
    },
  );

  test('mark-all-read failure preserves unread state', () async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..markAllError = Exception('backend failed');
    final controller = CourierNotificationsController(api: api);
    await controller.loadNotifications();

    expect(controller.markAllRead(), throwsException);
    expect(controller.notifications.single.isRead, isFalse);
    expect(controller.unreadCount, 1);
  });

  test(
    'controller clear prevents cross-courier notification leakage',
    () async {
      final controller = CourierNotificationsController(
        api: _FakeNotificationsApi(
          notifications: [_notification(id: '1', orderId: '123')],
          unreadCount: 1,
        ),
      );
      await controller.loadNotifications();

      controller.clear();

      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount, 0);
      expect(controller.errorMessage, isNull);
    },
  );

  testWidgets('notifications view shows loading, error, and retry', (
    WidgetTester tester,
  ) async {
    final failedLoad = Completer<List<CourierNotification>>();
    final successfulLoad = Completer<List<CourierNotification>>();
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..loadCompleter = failedLoad;
    final controller = CourierNotificationsController(api: api);

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: controller,
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    failedLoad.completeError(Exception('network failed'));
    await tester.pump();
    expect(find.text('تعذر تحميل الإشعارات'), findsOneWidget);

    api.loadCompleter = successfulLoad;
    await tester.tap(find.byKey(const Key('courier_notifications_retry')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    successfulLoad.complete(api.notifications);
    await tester.pump();

    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);
  });

  testWidgets('unread cards mark read before opening details', (
    WidgetTester tester,
  ) async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();

    expect(api.markReadCalls, ['1']);
    expect(find.text('تفاصيل الإشعار'), findsOneWidget);
  });

  testWidgets('mark-all-read updates loaded records and badge after success', (
    WidgetTester tester,
  ) async {
    var unread = -1;
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (count) => unread = count,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('courier_notifications_mark_all')));
    await tester.pump();

    expect(api.markAllCalls, 1);
    expect(unread, 0);
    expect(find.text('كل الإشعارات مقروءة'), findsOneWidget);
  });

  testWidgets('failed delete keeps the notification card visible', (
    WidgetTester tester,
  ) async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..deleteError = Exception('delete failed');

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('courier_notification_1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(api.deleteCalls, ['1']);
    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);
  });

  testWidgets('swiping either direction removes courier notifications', (
    WidgetTester tester,
  ) async {
    final api = _FakeNotificationsApi(
      notifications: [
        _notification(id: '1', orderId: '123'),
        _notification(id: '2', orderId: '124'),
      ],
      unreadCount: 2,
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('courier_notification_delete_1')),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const ValueKey('courier_notification_1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('courier_notification_2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(api.deleteCalls, ['1', '2']);
    expect(find.byKey(const ValueKey('courier_notification_1')), findsNothing);
    expect(find.byKey(const ValueKey('courier_notification_2')), findsNothing);
  });

  testWidgets('opening linked order loads the real courier order', (
    WidgetTester tester,
  ) async {
    CourierOrder? opened;
    final notificationsApi = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );
    final ordersApi = _FakeOrdersApi(
      orders: {
        '123': _order(
          id: '123',
          status: CourierOrderStatus.assigned,
          expectedDeliveryAt: DateTime(2026, 7, 8, 10),
        ),
      },
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: notificationsApi),
          ordersApi: ordersApi,
          onOrderTap: (order) => opened = order,
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الطلب'));
    await tester.pumpAndSettle();

    expect(ordersApi.loadOrderCalls, ['123']);
    expect(opened?.id, '123');
  });

  testWidgets('missing linked order shows an error and does not crash', (
    WidgetTester tester,
  ) async {
    final notificationsApi = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );
    final ordersApi = _FakeOrdersApi()..loadError = Exception('404');

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: notificationsApi),
          ordersApi: ordersApi,
          onOrderTap: (_) => fail('should not open unavailable order'),
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الطلب'));
    await tester.pumpAndSettle();

    expect(ordersApi.loadOrderCalls, ['123']);
    expect(find.text('هذا الطلب لم يعد متاحا لك.'), findsOneWidget);
  });

  test('no runtime code generates notifications from CourierOrder', () {
    final source = _readSources([
      'lib/features/deliveries/presentation/views/courier_notifications_view.dart',
      'lib/features/deliveries/presentation/views/courier_notifications_content_part.dart',
    ]);
    final controllerSource = File(
      'lib/features/deliveries/presentation/controllers/courier_notifications_controller.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('fromOrder')));
    expect(source, isNot(contains('assigned-')));
    expect(source, isNot(contains('delivered-')));
    expect(source, isNot(contains('expectedDeliveryAt')));
    expect(controllerSource, isNot(contains('_readIds')));
    expect(controllerSource, isNot(contains('_dismissedIds')));
  });

  testWidgets('tapping header bell opens notifications and back returns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: const _OrdersNotificationsRouteHost(),
        ),
      ),
    );

    expect(find.text('طلبات التوصيل'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-bottom-orders')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('الإشعارات'));
    await tester.pumpAndSettle();

    final backButton = find.byKey(
      const Key('courier_notifications_back_button'),
    );
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.byType(CourierNotificationsView), findsOneWidget);
    expect(backButton, findsOneWidget);
    final backIcon = tester.widget<Icon>(
      find.descendant(of: backButton, matching: find.byType(Icon)),
    );
    expect(backIcon.icon?.codePoint, 0xe936);
    expect(backIcon.icon?.fontFamily, 'iconsax');
    expect(backIcon.size, 21);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(CourierNotificationsView), findsNothing);
    expect(find.text('طلبات التوصيل'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-bottom-orders')),
      findsOneWidget,
    );
  });

  testWidgets(
    'notifications header back button and mark-all survive narrow width',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var unreadCount = -1;

      await tester.pumpWidget(
        _TestApp(
          child: CourierNotificationsView(
            controller: CourierNotificationsController(
              api: _FakeNotificationsApi(
                notifications: [_notification(id: '1', orderId: '123')],
                unreadCount: 1,
              ),
            ),
            ordersApi: _FakeOrdersApi(),
            onOrderTap: (_) {},
            onUnreadCountChanged: (count) => unreadCount = count,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final backButton = find.byKey(
        const Key('courier_notifications_back_button'),
      );
      expect(tester.takeException(), isNull);
      expect(backButton, findsOneWidget);
      expect(
        find.byKey(const Key('courier_notifications_mark_all')),
        findsOneWidget,
      );
      expect(unreadCount, 1);

      await tester.tap(find.byKey(const Key('courier_notifications_mark_all')));
      await tester.pump();

      expect(unreadCount, 0);
    },
  );
}
