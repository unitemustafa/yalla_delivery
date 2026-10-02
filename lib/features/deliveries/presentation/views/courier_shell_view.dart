import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/notifications/courier_push_service.dart';
import '../../../../core/routing/app_routes.dart';
import '../../data/courier_notifications_api.dart';
import '../../../../core/di/courier_orders_factory.dart';
import '../controllers/courier_order_actions_cubit.dart';
import '../controllers/courier_orders_cubit.dart';
import '../../domain/courier_order.dart';
import '../controllers/courier_notifications_controller.dart';
import '../controllers/courier_profile_controller.dart';
import '../widgets/delivery_confirmation_sheet.dart';
import 'courier_notifications_view.dart';
import 'courier_orders_view.dart';
import 'courier_profile_view.dart';
import 'delivered_history_view.dart';
import 'delivered_summary_view.dart';
import 'order_details_view.dart';

class CourierShellView extends StatefulWidget {
  const CourierShellView({super.key});

  @override
  State<CourierShellView> createState() => _CourierShellViewState();
}

class _CourierShellViewState extends State<CourierShellView>
    with WidgetsBindingObserver {
  final _actions = courierDependency<CourierOrderActionsCubit>();
  final _ordersCubit = courierDependency<CourierOrdersCubit>();
  StreamSubscription<CourierOrdersState>? _ordersSubscription;
  final _notificationsApi = const CourierNotificationsApi();
  final _notificationsController = CourierNotificationsController();
  final _profileController = CourierProfileController();
  List<CourierOrder> get _orders => _ordersCubit.state.active;
  bool get _loading => _ordersCubit.state.loading && _orders.isEmpty;
  String? get _loadError => _orders.isEmpty ? _ordersCubit.state.error : null;
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription<CourierPushEvent>? _pushSubscription;
  Timer? _pushRefreshDebounce;
  bool _refreshingRemoteState = false;
  Future<void>? _ordersLoadInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ordersSubscription = _ordersCubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadOrders();
    unawaited(_ordersCubit.refreshHistory());
    unawaited(_profileController.loadAccountIfNeeded());
    unawaited(_refreshUnreadNotificationCount());
    _pushSubscription = CourierPushService.instance.events.listen(_onPushEvent);
    CourierPushService.instance.attachOpenedEventRouter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final event
          in CourierPushService.instance.takePendingOpenedEvents()) {
        _onPushEvent(event);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSubscription?.cancel();
    CourierPushService.instance.detachOpenedEventRouter();
    _ordersSubscription?.cancel();
    unawaited(_ordersCubit.close());
    unawaited(_actions.close());
    _pushRefreshDebounce?.cancel();
    _notificationsController.clear();
    _notificationsController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(CourierPushService.instance.retryRegistrationOnResume());
      unawaited(_refreshRemoteState());
    }
  }

  Future<void> _refreshRemoteState() async {
    if (!mounted || _refreshingRemoteState) return;

    _refreshingRemoteState = true;
    try {
      await AuthSession.instance.validateForForeground();
      await Future.wait([
        _loadOrders(),
        _profileController.refresh(),
        _refreshUnreadNotificationCount(),
      ]);
    } catch (_) {
      // A temporary refresh failure must not interrupt the courier workflow.
    } finally {
      _refreshingRemoteState = false;
    }
  }

  void _onPushEvent(CourierPushEvent event) {
    if (!mounted) return;
    final type = event.event;
    if (type == 'courier_account_disabled') return;
    if (event.opened && type == 'courier_order_assigned') {
      unawaited(_openAssignedPush(event.data));
    }
    _pushRefreshDebounce?.cancel();
    _pushRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (type == 'courier_profile_updated' ||
          type == 'courier_availability_changed') {
        unawaited(_profileController.refresh());
      } else {
        unawaited(_loadOrders());
      }
      unawaited(_refreshUnreadNotificationCount());
    });
  }

  Future<void> _openAssignedPush(Map<String, dynamic> data) async {
    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    try {
      final order = await _actions.loadOrder(orderId);
      if (!mounted) return;
      if (!order.isActiveCourierOrder) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يعد هذا الطلب معينًا لك.')),
        );
        await _loadOrders();
        return;
      }
      _openOrderDetails(order);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يعد هذا الطلب متاحًا لك.')),
      );
      await _loadOrders();
    }
  }

  List<CourierOrder> get _activeOrders {
    return _orders.where((order) => order.isActiveCourierOrder).toList();
  }

  List<CourierOrder> get _deliveredOrders {
    return _ordersCubit.state.history;
  }

  Future<void> _loadOrders() async {
    final activeLoad = _ordersLoadInFlight;
    if (activeLoad != null) return activeLoad;

    final loadFuture = _performLoadOrders();
    _ordersLoadInFlight = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_ordersLoadInFlight, loadFuture)) {
        _ordersLoadInFlight = null;
      }
    }
  }

  Future<void> _performLoadOrders() => _ordersCubit.refreshActive();

  Future<void> _refreshOrdersAndUnread() async {
    await Future.wait([
      _loadOrders(),
      _ordersCubit.refreshHistory(),
      _refreshUnreadNotificationCount(),
    ]);
  }

  Future<CourierOrder> _markPickedUp(String orderId) async {
    final pickedUp = await _actions.markPickedUp(orderId);
    if (!mounted) return pickedUp;
    setState(() => _replaceOrder(pickedUp));
    unawaited(_refreshUnreadNotificationCount());
    return pickedUp;
  }

  Future<CourierOrder> _markMarketPickedUp(
    String orderId,
    int sectionId,
  ) async {
    final updated = await _actions.markMarketPickedUp(orderId, sectionId);
    if (mounted) setState(() => _replaceOrder(updated));
    return updated;
  }

  Future<CourierOrder> _markDelivered(
    String orderId,
    DeliveryConfirmationResult result,
  ) async {
    final delivered = await _actions.markDelivered(
      orderId,
      note: result.note,
      proofBytes: result.proofBytes,
      proofName: result.proofName,
    );
    if (!mounted) return delivered;
    setState(() {
      _replaceOrder(delivered);
      _selectedIndex = 1;
    });
    unawaited(_refreshUnreadNotificationCount());
    unawaited(_ordersCubit.refreshHistory());
    return delivered;
  }

  void _replaceOrder(CourierOrder updated) =>
      _ordersCubit.replaceOrder(updated);

  Future<void> _logout() async {
    _notificationsController.clear();
    await AuthSession.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CourierOrdersView(
        orders: _activeOrders,
        onPickedUp: _markPickedUp,
        onMarketPickedUp: _markMarketPickedUp,
        onDelivered: _markDelivered,
        onRefresh: _refreshOrdersAndUnread,
        unreadNotificationCount: _unreadNotificationCount,
        onNotificationsPressed: _openNotifications,
      ),
      DeliveredHistoryView(
        orders: _deliveredOrders,
        totals: _ordersCubit.state.totals,
        hasNext: _ordersCubit.state.hasNext,
        loadingMore: _ordersCubit.state.loadingHistory,
        error: _ordersCubit.state.historyError,
        onLoadMore: _ordersCubit.loadMoreHistory,
        onRefresh: _refreshOrdersAndUnread,
        unreadNotificationCount: _unreadNotificationCount,
        onNotificationsPressed: _openNotifications,
      ),
      CourierProfileView(
        controller: _profileController,
        activeOrders: _activeOrders.length,
        deliveredOrders: _ordersCubit.state.totals?.count ?? 0,
        onActiveOrdersTap: () => setState(() => _selectedIndex = 0),
        onDeliveredSummaryTap: _openDeliveredSummary,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            : IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: _CourierBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
          if (index == 2) unawaited(_profileController.refresh());
        },
      ),
    );
  }

  void _openDeliveredSummary() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const DeliveredSummaryView(orders: [], remote: true),
      ),
    );
  }

  void _openOrderDetails(CourierOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsView(
          order: order,
          onPickedUp: _markPickedUp,
          onMarketPickedUp: _markMarketPickedUp,
          onDelivered: _markDelivered,
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await _notificationsController.refreshNotifications();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: CourierNotificationsView(
              controller: _notificationsController,
              onOrderTap: _openOrderDetails,
              onUnreadCountChanged: _updateUnreadNotificationCount,
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _refreshUnreadNotificationCount();
  }

  void _updateUnreadNotificationCount(int count) {
    if (_unreadNotificationCount == count) return;
    setState(() => _unreadNotificationCount = count);
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final count = await _notificationsApi.loadUnreadCount();
      if (!mounted) return;
      _updateUnreadNotificationCount(count);
    } catch (_) {
      // Notification badge failures should not block the orders experience.
    }
  }
}

class _CourierBottomNavigationBar extends StatelessWidget {
  const _CourierBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    _NavigationItemData(
      label: 'الطلبات',
      icon: AppIcons.receipt_text,
      activeIcon: AppIcons.truck_fast,
    ),
    _NavigationItemData(
      label: 'المسلّمة',
      icon: AppIcons.document_text,
      activeIcon: AppIcons.tick_circle,
    ),
    _NavigationItemData(
      label: 'حسابي',
      icon: AppIcons.user,
      activeIcon: AppIcons.profile_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: Container(
        height: 78,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            return Expanded(
              child: _NavigationBarItem(
                item: _items[index],
                isSelected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationBarItem extends StatelessWidget {
  const _NavigationBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavigationItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = AppColors.lightTextSecondary;
    final labelColor = isSelected ? AppColors.primary : inactiveColor;
    final indicatorColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.11)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 52,
                    height: 32,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: labelColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItemData {
  const _NavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
