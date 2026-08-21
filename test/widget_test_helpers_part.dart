part of 'widget_test.dart';

class DeliveryConfirmationSheetHost extends StatelessWidget {
  const DeliveryConfirmationSheetHost({super.key, required this.onResult});

  final ValueChanged<DeliveryConfirmationResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          final result = await showModalBottomSheet<DeliveryConfirmationResult>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const DeliveryConfirmationSheet(orderId: 'YM-1'),
          );
          if (result != null) onResult(result);
        },
        child: const Text('فتح تأكيد التسليم'),
      ),
    );
  }
}

class _OrdersNotificationsRouteHost extends StatelessWidget {
  const _OrdersNotificationsRouteHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourierOrdersView(
        orders: const [],
        onPickedUp: (orderId) async => _order(
          id: orderId,
          status: CourierOrderStatus.pickedUp,
          expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
        ),
        onDelivered: (orderId, result) async => _order(
          id: orderId,
          status: CourierOrderStatus.delivered,
          expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
        ),
        onRefresh: () async {},
        unreadNotificationCount: 1,
        onNotificationsPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: CourierNotificationsView(
                  controller: CourierNotificationsController(
                    api: _FakeNotificationsApi(),
                  ),
                  ordersApi: _FakeOrdersApi(),
                  onOrderTap: (_) {},
                  onUnreadCountChanged: (_) {},
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text('الطلبات', key: ValueKey('selected-bottom-orders')),
            ),
            Expanded(child: Text('المسلّمة')),
            Expanded(child: Text('حسابي')),
          ],
        ),
      ),
    );
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }
}

class _FakeProfileApi extends CourierProfileApi {
  _FakeProfileApi({List<CourierAccount>? accounts})
    : accounts = accounts ?? const [];

  List<CourierAccount> accounts;
  Completer<CourierAccount>? loadCompleter;
  Object? loadError;
  int loadCalls = 0;

  @override
  Future<CourierAccount> loadAccount() async {
    loadCalls += 1;
    final completer = loadCompleter;
    if (completer != null) {
      loadCompleter = null;
      return completer.future;
    }
    if (loadError != null) throw loadError!;
    if (accounts.isEmpty) return _courierAccount();
    if (accounts.length == 1) return accounts.single;
    return accounts.removeAt(0);
  }
}

CourierProfileController _profileControllerWith(List<CourierAccount> accounts) {
  return CourierProfileController(api: _FakeProfileApi(accounts: accounts));
}

CourierAccount _courierAccount({
  bool? isAvailable = true,
  String serviceCityName = 'الجيزة',
  String? avatarUrl,
}) {
  return CourierAccount.fromJson(
    _courierAccountJson(
      isAvailable: isAvailable,
      serviceCityName: serviceCityName,
      avatarUrl: avatarUrl,
    ),
  );
}

Map<String, dynamic> _courierAccountJson({
  bool? isAvailable = true,
  String serviceCityName = 'الجيزة',
  String? avatarUrl = '/media/avatars/courier.png',
}) {
  final courierProfile = <String, dynamic>{
    'vehicle_type': 'دراجة نارية',
    'plate_number': 'ج ي ز 1234',
    'delivery_area': null,
    'service_city': 2,
    'service_city_name': serviceCityName,
    'max_active_orders': 4,
  };
  if (isAvailable != null) {
    courierProfile['is_available'] = isAvailable;
  }

  return {
    'id': '7',
    'first_name': 'مصطفى',
    'last_name': 'علي',
    'username': 'captain_mostafa',
    'email': 'captain@example.com',
    'phone': '+201001234567',
    'avatar_url': avatarUrl,
    'role': 'representative',
    'courier_profile': courierProfile,
  };
}

class _FakeNotificationsApi extends CourierNotificationsApi {
  _FakeNotificationsApi({
    List<CourierNotification>? notifications,
    this.unreadCount = 0,
  }) : notifications = notifications ?? const [];

  List<CourierNotification> notifications;
  int unreadCount;
  Object? loadError;
  Completer<List<CourierNotification>>? loadCompleter;
  Object? markReadError;
  Object? markAllError;
  Object? deleteError;
  int loadCalls = 0;
  int markAllCalls = 0;
  final List<String> markReadCalls = [];
  final List<String> deleteCalls = [];

  @override
  Future<List<CourierNotification>> loadNotifications() async {
    loadCalls += 1;
    final completer = loadCompleter;
    if (completer != null) {
      loadCompleter = null;
      return completer.future;
    }
    if (loadError != null) throw loadError!;
    return notifications;
  }

  @override
  Future<int> loadUnreadCount() async {
    if (loadError != null) throw loadError!;
    return unreadCount;
  }

  @override
  Future<CourierNotification> markRead(
    String notificationId, {
    CourierNotification? current,
  }) async {
    markReadCalls.add(notificationId);
    if (markReadError != null) throw markReadError!;
    final updated =
        (current ??
                notifications.firstWhere(
                  (notification) => notification.id == notificationId,
                ))
            .copyWith(isRead: true, readAt: DateTime.now());
    notifications = [
      for (final notification in notifications)
        if (notification.id == notificationId) updated else notification,
    ];
    unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;
    return updated;
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls += 1;
    if (markAllError != null) throw markAllError!;
    final previousUnread = unreadCount;
    notifications = [
      for (final notification in notifications)
        notification.copyWith(isRead: true, readAt: DateTime.now()),
    ];
    unreadCount = 0;
    return previousUnread;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    deleteCalls.add(notificationId);
    if (deleteError != null) throw deleteError!;
    final removed = notifications
        .where((notification) => notification.id == notificationId)
        .toList();
    notifications = [
      for (final notification in notifications)
        if (notification.id != notificationId) notification,
    ];
    if (removed.any((notification) => !notification.isRead) &&
        unreadCount > 0) {
      unreadCount -= 1;
    }
  }
}

class _FakeOrdersApi extends CourierOrdersApi {
  _FakeOrdersApi({Map<String, CourierOrder>? orders}) : orders = orders ?? {};

  final Map<String, CourierOrder> orders;
  final List<String> loadOrderCalls = [];
  Object? loadError;

  @override
  Future<CourierOrder> loadOrder(String orderId) async {
    loadOrderCalls.add(orderId);
    if (loadError != null) throw loadError!;
    final order = orders[orderId];
    if (order == null) throw Exception('not found');
    return order;
  }
}

CourierNotification _notification({
  required String id,
  String? orderId,
  bool isRead = false,
}) {
  return CourierNotification.fromJson(
    _notificationJson(id: int.parse(id), orderId: orderId, isRead: isRead),
  );
}

Map<String, dynamic> _notificationJson({
  required int id,
  Object? orderId = 123,
  bool isRead = false,
}) {
  return {
    'id': id,
    'audience': 'courier',
    'type': 'order_assigned',
    'title': 'New order assigned',
    'message': 'A new order has been assigned to you.',
    'order_id': orderId,
    'is_read': isRead,
    'is_blocking': false,
    'is_resolved': false,
    'read_at': null,
    'resolved_at': null,
    'created_at': '2026-07-08T09:15:00Z',
  };
}

CourierOrder _order({
  String id = 'YM-1',
  required CourierOrderStatus status,
  required DateTime expectedDeliveryAt,
  DateTime? deliveredAt,
}) {
  return CourierOrder(
    id: id,
    customerName: 'أحمد مصطفى',
    phone: '+201001234567',
    address: 'شارع التحرير، الدقي',
    area: 'الدقي',
    total: 845,
    deliveryPrice: 45,
    status: status,
    rawStatus: switch (status) {
      CourierOrderStatus.assigned => 'assigned',
      CourierOrderStatus.pickedUp => 'picked_up',
      CourierOrderStatus.delivered => 'delivered',
      _ => status.name,
    },
    createdAt: expectedDeliveryAt.subtract(const Duration(hours: 1)),
    expectedDeliveryAt: expectedDeliveryAt,
    itemsCount: 1,
    marketName: 'محل تجريبي',
    marketBranch: 'فرع تجريبي',
    marketCount: 1,
    marketSummary: 'محل تجريبي',
    deliveredAt: deliveredAt,
    items: const [
      CourierOrderItem(name: 'منتج تجريبي', quantity: 1, price: 845),
    ],
  );
}
