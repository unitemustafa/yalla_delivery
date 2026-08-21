import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../data/courier_orders_api.dart';
import '../../domain/courier_notification.dart';
import '../../domain/courier_order.dart';
import '../controllers/courier_notifications_controller.dart';

part 'courier_notifications_content_part.dart';

class CourierNotificationsView extends StatefulWidget {
  const CourierNotificationsView({
    super.key,
    required this.onOrderTap,
    required this.onUnreadCountChanged,
    this.controller,
    this.ordersApi = const CourierOrdersApi(),
  });

  final ValueChanged<CourierOrder> onOrderTap;
  final ValueChanged<int> onUnreadCountChanged;
  final CourierNotificationsController? controller;
  final CourierOrdersApi ordersApi;

  @override
  State<CourierNotificationsView> createState() =>
      _CourierNotificationsViewState();
}

class _CourierNotificationsViewState extends State<CourierNotificationsView> {
  late final CourierNotificationsController _controller =
      widget.controller ?? CourierNotificationsController();
  late final bool _ownsController = widget.controller == null;
  bool _openingOrder = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadNotificationsIfNeeded();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    widget.onUnreadCountChanged(_controller.unreadCount);
    setState(() {});
  }

  Future<void> _markAllRead() async {
    try {
      await _controller.markAllRead();
      if (!mounted) return;
      CustomSnackBar.showSuccess(
        context: context,
        title: 'تم تعليم الإشعارات كمقروءة',
      );
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
    }
  }

  Future<bool> _confirmDelete(CourierNotification notification) async {
    try {
      await _controller.deleteNotification(notification);
      if (!mounted) return true;
      CustomSnackBar.showSuccess(context: context, title: 'تم حذف الإشعار');
      return true;
    } catch (error) {
      if (!mounted) return false;
      CustomSnackBar.showError(context: context, title: error.toString());
      return false;
    }
  }

  Future<CourierNotification> _markReadIfNeeded(
    CourierNotification notification,
  ) async {
    if (notification.isRead) return notification;
    try {
      return await _controller.markRead(notification);
    } catch (error) {
      if (mounted) {
        CustomSnackBar.showError(context: context, title: error.toString());
      }
      rethrow;
    }
  }

  Future<void> _openNotification(CourierNotification notification) async {
    CourierNotification visibleNotification = notification;
    if (!notification.isRead) {
      try {
        visibleNotification = await _markReadIfNeeded(notification);
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationDetailSheet(
          data: visibleNotification,
          openingOrder: _openingOrder,
          onOrderTap: () async {
            Navigator.pop(sheetContext);
            await _openLinkedOrder(visibleNotification);
          },
        );
      },
    );
  }

  Future<void> _openLinkedOrder(CourierNotification notification) async {
    final orderId = notification.orderId;
    if (orderId == null || orderId.isEmpty) {
      CustomSnackBar.showError(
        context: context,
        title: 'هذا الطلب لم يعد متاحا لك.',
      );
      return;
    }

    if (_openingOrder) return;
    setState(() => _openingOrder = true);
    try {
      final readNotification = await _markReadIfNeeded(notification);
      final id = readNotification.orderId ?? orderId;
      final order = await widget.ordersApi.loadOrder(id);
      if (!mounted) return;
      widget.onOrderTap(order);
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.showError(
        context: context,
        title: 'هذا الطلب لم يعد متاحا لك.',
      );
    } finally {
      if (mounted) setState(() => _openingOrder = false);
    }
  }

  Future<void> _refresh() => _controller.refreshNotifications();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : const Color(0xFFF7F8FB);
    final notifications = _controller.notifications;
    final isInitialLoading =
        _controller.isLoading &&
        notifications.isEmpty &&
        _controller.errorMessage == null;

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageTopBar(
                          title: 'الإشعارات',
                          subtitle: 'تنبيهات الطلبات وحالة التسليم',
                          showBackButton: true,
                          backButtonKey: const Key(
                            'courier_notifications_back_button',
                          ),
                          onBackPressed: () => Navigator.maybePop(context),
                          actions: [
                            _NotificationActionButton(
                              key: const Key('courier_notifications_mark_all'),
                              isDark: isDark,
                              icon: AppIcons.tick_circle,
                              tooltip: 'تعليم الكل كمقروء',
                              onPressed:
                                  _controller.unreadCount == 0 ||
                                      _controller.isMarkingAllRead
                                  ? null
                                  : _markAllRead,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _NotificationSummary(
                          isDark: isDark,
                          unreadCount: _controller.unreadCount,
                          totalCount: notifications.length,
                        ),
                        const SizedBox(height: 22),
                        if (isInitialLoading)
                          const _NotificationsLoadingView()
                        else if (_controller.errorMessage != null &&
                            notifications.isEmpty)
                          _NotificationsErrorView(
                            message: _controller.errorMessage!,
                            onRetry: _controller.loadNotifications,
                          )
                        else if (notifications.isEmpty)
                          const _EmptyNotificationsView()
                        else ...[
                          Text(
                            'اليوم',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          for (final notification in notifications)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: ValueKey(
                                  'courier_notification_${notification.id}',
                                ),
                                direction: DismissDirection.horizontal,
                                background:
                                    const _NotificationDismissBackground(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                    ),
                                secondaryBackground:
                                    const _NotificationDismissBackground(
                                      alignment: AlignmentDirectional.centerEnd,
                                    ),
                                confirmDismiss: (_) =>
                                    _confirmDelete(notification),
                                child: _NotificationCard(
                                  data: notification,
                                  isDark: isDark,
                                  isDeleting: _controller.isDeleting(
                                    notification,
                                  ),
                                  onTap: () => _openNotification(notification),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
