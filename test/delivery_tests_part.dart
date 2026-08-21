part of 'widget_test.dart';

void _registerDeliveryTests() {
  testWidgets('hides active order time and shows delivered time', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12, 43);
    final activeOrder = _order(
      status: CourierOrderStatus.assigned,
      expectedDeliveryAt: now,
    );
    final deliveredOrder = _order(
      status: CourierOrderStatus.delivered,
      expectedDeliveryAt: now,
      deliveredAt: now,
    );

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(order: activeOrder, onTap: () {}),
      ),
    );

    expect(find.text('الوصول'), findsNothing);
    expect(find.text('12:43'), findsNothing);
    expect(find.text('مطلوب الاستلام'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(
          order: deliveredOrder,
          showDeliveredMeta: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('وقت التسليم'), findsOneWidget);
    expect(find.text('15/06 12:43'), findsOneWidget);
  });

  testWidgets('delivered card shows fallback when delivered time is absent', (
    WidgetTester tester,
  ) async {
    final deliveredOrder = _order(
      status: CourierOrderStatus.delivered,
      expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
    );

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(
          order: deliveredOrder,
          showDeliveredMeta: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('---'), findsOneWidget);
  });

  testWidgets('delivered card fits compact iPhone width with larger text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _TestApp(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: OrderCard(
              order: _order(
                status: CourierOrderStatus.delivered,
                expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
                deliveredAt: DateTime(2026, 6, 15, 12, 43),
              ),
              showDeliveredMeta: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('وقت التسليم'), findsOneWidget);
    expect(find.text('845 جنيه'), findsOneWidget);
  });

  test('parses delivered_at before delivered history events', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'delivered_at': '2026-06-15T12:43:00Z',
      'history': [
        {'to_status': 'delivered', 'created_at': '2026-06-15T11:30:00Z'},
      ],
    });

    expect(order.deliveredAt, DateTime.parse('2026-06-15T12:43:00Z').toLocal());
  });

  test('falls back to latest delivered history event only', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'delivered_at': null,
      'history': [
        {'to_status': 'picked_up', 'created_at': '2026-06-15T10:30:00Z'},
        {'to_status': 'delivered', 'created_at': '2026-06-15T11:30:00Z'},
        {'to_status': 'delivered', 'created_at': '2026-06-15T12:43:00Z'},
      ],
    });

    expect(order.deliveredAt, DateTime.parse('2026-06-15T12:43:00Z').toLocal());
  });

  test('keeps deliveredAt null without an authoritative delivered time', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'updated_at': '2026-06-15T12:43:00Z',
      'history': [
        {'to_status': 'picked_up', 'created_at': '2026-06-15T10:30:00Z'},
      ],
    });

    expect(order.deliveredAt, isNull);
  });

  test('uses manual delivery area before the generic area fallback', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-07-14T05:00:00Z',
      'delivery_address': {
        'manual_area': 'منطقة اختبار الإطلاق',
        'manual_city': 'القاهرة',
      },
    });

    expect(order.area, 'منطقة اختبار الإطلاق');
  });

  test('parses authoritative courier statuses and safe legacy statuses', () {
    expect(courierOrderStatusFromRaw('assigned'), CourierOrderStatus.assigned);
    expect(CourierOrderStatus.assigned.label, 'مطلوب الاستلام');
    expect(courierOrderStatusFromRaw('ready'), CourierOrderStatus.assigned);
    expect(
      courierOrderStatusFromRaw('on_the_way'),
      CourierOrderStatus.pickedUp,
    );
    expect(
      courierOrderStatusFromRaw('under_preparation'),
      CourierOrderStatus.confirmed,
    );
  });

  test('courier lifecycle helpers expose the allowed courier actions', () {
    expect(CourierOrderStatus.assigned.requiresPickup, isTrue);
    expect(CourierOrderStatus.assigned.canMarkPickedUp, isTrue);
    expect(CourierOrderStatus.assigned.canMarkDelivered, isFalse);
    expect(CourierOrderStatus.pickedUp.canMarkPickedUp, isFalse);
    expect(CourierOrderStatus.pickedUp.canMarkDelivered, isTrue);

    final activeStatuses = CourierOrderStatus.values
        .where((status) => status.isActiveCourierOrder)
        .toList();
    expect(activeStatuses, [
      CourierOrderStatus.assigned,
      CourierOrderStatus.pickedUp,
    ]);

    final pickedUpOrder = _order(
      status: CourierOrderStatus.assigned,
      expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
    ).copyWith(status: CourierOrderStatus.pickedUp, rawStatus: 'picked_up');
    final deliveredOrder = pickedUpOrder.copyWith(
      status: CourierOrderStatus.delivered,
      rawStatus: 'delivered',
      deliveredAt: DateTime(2026, 6, 15, 13, 10),
      deliveryNote: 'تم التسليم للعميل',
    );

    expect(pickedUpOrder.canMarkDelivered, isTrue);
    expect(deliveredOrder.isDelivered, isTrue);
    expect(deliveredOrder.canMarkDelivered, isFalse);
    expect(deliveredOrder.deliveryNote, 'تم التسليم للعميل');
  });

  testWidgets(
    'delivery confirmation accepts optional notes and offers camera proof',
    (WidgetTester tester) async {
      DeliveryConfirmationResult? result;

      await tester.pumpWidget(
        _TestApp(
          child: DeliveryConfirmationSheetHost(
            onResult: (value) => result = value,
          ),
        ),
      );

      await tester.tap(find.text('فتح تأكيد التسليم'));
      await tester.pumpAndSettle();

      expect(find.text('التقاط صورة إثبات التسليم'), findsOneWidget);
      expect(find.text('المعرض'), findsNothing);
      expect(find.text('لا توجد صورة مرفوعة'), findsNothing);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('delivery-proof-capture-button')),
            )
            .width,
        greaterThan(300),
      );

      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result?.note, isNull);

      result = null;
      await tester.tap(find.text('فتح تأكيد التسليم'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'تم التسليم للعميل');
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(result?.note, 'تم التسليم للعميل');
    },
  );

  test('delivery confirmation API supports JSON and multipart updates', () {
    final source = File(
      'lib/features/deliveries/data/courier_orders_api.dart',
    ).readAsStringSync();

    expect(source, contains('patchJson'));
    expect(source, contains("'status': 'delivered'"));
    expect(source, contains("'delivery_note': deliveryNote"));
    expect(
      source,
      contains('if (deliveryNote != null && deliveryNote.isNotEmpty)'),
    );
    expect(source, isNot(contains('DeliveryProof')));
    expect(source, contains('patchMultipart'));
    expect(source, contains('proofBytes'));
    expect(source, contains('proofName'));
    expect(source, isNot(contains('deliveryProof')));
  });

  test('order details exposes enabled contact and customer map actions', () {
    final source = _readSources([
      'lib/features/deliveries/presentation/views/order_details_view.dart',
      'lib/features/deliveries/presentation/views/order_details_sections_part.dart',
      'lib/features/deliveries/presentation/views/order_contact_options_part.dart',
    ]);

    expect(source, contains("label: const Text('تواصل')"));
    expect(source, contains('onPressed: () => _showContactOptions(context)'));
    expect(source, contains('onPressed: () => _openCustomerMap(context)'));
    expect(source, contains("label: const Text('الخريطة')"));
    expect(source, contains("Uri.https('www.google.com', '/maps/dir/'"));
    expect(source, contains("'destination': query"));
    expect(source, contains("'travelmode': 'driving'"));
    expect(source, contains('_DeliveredTimeBadge'));
    expect(source, contains("'وقت التسليم'"));
    expect(source, isNot(contains('CourierTrackingMapView')));
    expect(source, isNot(contains('courier_tracking_map_view.dart')));
  });

  testWidgets('orders screen receives active orders without status filters', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12, 43);

    await tester.pumpWidget(
      _TestApp(
        child: CourierOrdersView(
          orders: [
            _order(
              id: 'YM-1',
              status: CourierOrderStatus.assigned,
              expectedDeliveryAt: now,
            ),
            _order(
              id: 'YM-2',
              status: CourierOrderStatus.pickedUp,
              expectedDeliveryAt: now,
            ),
          ],
          onPickedUp: (orderId) async => _order(
            id: orderId,
            status: CourierOrderStatus.pickedUp,
            expectedDeliveryAt: now,
          ),
          onDelivered: (orderId, DeliveryConfirmationResult result) async =>
              _order(
                id: orderId,
                status: CourierOrderStatus.delivered,
                expectedDeliveryAt: now,
                deliveredAt: now,
              ),
          onRefresh: () async {},
          unreadNotificationCount: 2,
          onNotificationsPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('الإشعارات'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('مطلوب الاستلام'), findsWidgets);
    expect(find.text('تم الاستلام'), findsWidgets);
  });

  testWidgets('delivered header shows bell and requested subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: DeliveredHistoryView(
          orders: [
            _order(
              status: CourierOrderStatus.delivered,
              expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
              deliveredAt: DateTime(2026, 6, 15, 12, 43),
            ),
          ],
          onRefresh: () async {},
          unreadNotificationCount: 3,
          onNotificationsPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('الإشعارات'), findsOneWidget);
    expect(find.text('الطلبات المسلّمة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  test('bottom navigation source has exactly Orders, Delivered, Account', () {
    final source = File(
      'lib/features/deliveries/presentation/views/courier_shell_view.dart',
    ).readAsStringSync();

    expect(source, contains('List.generate(_items.length'));
    expect(source, isNot(contains('notificationBadgeCount')));
    expect(source, isNot(contains('notification_bing')));
    expect(
      RegExp(r'^\s+_NavigationItemData\(', multiLine: true).allMatches(source),
      hasLength(3),
    );
  });

  test('historical delivery proof display support remains intact', () {
    final source = _readSources([
      'lib/features/deliveries/presentation/views/order_details_view.dart',
      'lib/features/deliveries/presentation/views/order_details_sections_part.dart',
      'lib/features/deliveries/presentation/views/order_contact_options_part.dart',
    ]);

    expect(source, contains('order.deliveryProof'));
    expect(source, contains('order.deliveryProofUrl'));
    expect(source, contains('NetworkImageOrPlaceholder'));
    expect(source, contains('Image.memory'));
  });

  testWidgets('network image placeholder accepts unconstrained width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NetworkImageOrPlaceholder(
            url: null,
            placeholderAsset: AppAssets.defaultProduct,
            width: double.infinity,
            height: 160,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
