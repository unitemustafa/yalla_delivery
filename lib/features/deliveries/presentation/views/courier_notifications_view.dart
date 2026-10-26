import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/texts/app_texts.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../../../core/domain/api_result.dart';
import '../../../../core/di/courier_orders_factory.dart';
import '../../domain/courier_orders_use_cases.dart';
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
    this.loadOrder,
  });

  final ValueChanged<CourierOrder> onOrderTap;
  final ValueChanged<int> onUnreadCountChanged;
  final CourierNotificationsController? controller;
  final LoadCourierOrder? loadOrder;

  @override
  State<CourierNotificationsView> createState() =>
      _CourierNotificationsViewState();
}

class _CourierNotificationsViewState extends State<CourierNotificationsView> {
  late final CourierNotificationsController _controller =
      widget.controller ?? courierDependency<CourierNotificationsController>();
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
        title: NotificationTexts.markedRead,
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
      CustomSnackBar.showSuccess(
        context: context,
        title: NotificationTexts.deleted,
      );
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
        title: NotificationTexts.orderUnavailable,
      );
      return;
    }

    if (_openingOrder) return;
    setState(() => _openingOrder = true);
    try {
      final readNotification = await _markReadIfNeeded(notification);
      final id = readNotification.orderId ?? orderId;
      final result =
          await (widget.loadOrder ?? courierDependency<LoadCourierOrder>())(id);
      if (!mounted) return;
      switch (result) {
        case ApiSuccess(:final data):
          widget.onOrderTap(data);
        case ApiFailure():
          throw const CourierNotificationActionException(
            NotificationTexts.orderUnavailable,
          );
      }
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.showError(
        context: context,
        title: NotificationTexts.orderUnavailable,
      );
    } finally {
      if (mounted) setState(() => _openingOrder = false);
    }
  }

  Future<void> _refresh() => _controller.refreshNotifications();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = _controller.notifications;
    final initialLoading =
        _controller.isLoading &&
        notifications.isEmpty &&
        _controller.errorMessage == null;
    final footer = _controller.hasNext || _controller.moreError != null;
    return ColoredBox(
      color: isDark ? AppColors.darkBackground : const Color(0xFFF7F8FB),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: 3 + notifications.length + (footer ? 1 : 0),
              separatorBuilder: (_, index) =>
                  SizedBox(height: index < 2 ? 18 : 10),
              itemBuilder: (context, index) {
                Widget content;
                if (index == 0) {
                  content = PageTopBar(
                    title: NotificationTexts.title,
                    subtitle: NotificationTexts.subtitle,
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
                        tooltip: NotificationTexts.markAllRead,
                        onPressed:
                            _controller.unreadCount == 0 ||
                                _controller.isMarkingAllRead
                            ? null
                            : _markAllRead,
                      ),
                    ],
                  );
                } else if (index == 1) {
                  content = _NotificationSummary(
                    isDark: isDark,
                    unreadCount: _controller.unreadCount,
                    totalCount: _controller.totalCount,
                  );
                } else if (index == 2) {
                  content = initialLoading
                      ? const _NotificationsLoadingView()
                      : _controller.errorMessage != null &&
                            notifications.isEmpty
                      ? _NotificationsErrorView(
                          message: _controller.errorMessage!,
                          onRetry: _controller.loadNotifications,
                        )
                      : notifications.isEmpty
                      ? const _EmptyNotificationsView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CommonTexts.today,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            if (_controller.errorMessage != null)
                              TextButton(
                                onPressed: _controller.loadNotifications,
                                child: Text(_controller.errorMessage!),
                              ),
                          ],
                        );
                } else if (index == notifications.length + 3) {
                  content = Column(
                    children: [
                      if (_controller.moreError != null)
                        Text(_controller.moreError!),
                      TextButton(
                        key: const ValueKey('courier_notifications_load_more'),
                        onPressed:
                            _controller.isLoadingMore || _controller.isLoading
                            ? null
                            : _controller.loadMore,
                        child: _controller.isLoadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(DeliveredTexts.loadMore),
                      ),
                    ],
                  );
                } else {
                  final notification = notifications[index - 3];
                  content = Dismissible(
                    key: ValueKey('courier_notification_${notification.id}'),
                    direction: DismissDirection.horizontal,
                    background: const _NotificationDismissBackground(
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    secondaryBackground: const _NotificationDismissBackground(
                      alignment: AlignmentDirectional.centerEnd,
                    ),
                    confirmDismiss: (_) => _confirmDelete(notification),
                    child: _NotificationCard(
                      data: notification,
                      isDark: isDark,
                      isDeleting: _controller.isDeleting(notification),
                      onTap: () => _openNotification(notification),
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: content,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
