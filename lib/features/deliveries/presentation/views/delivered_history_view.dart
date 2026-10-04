import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/texts/app_texts.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../../domain/courier_order_page.dart';
import '../widgets/courier_notifications_button.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

class DeliveredHistoryView extends StatelessWidget {
  const DeliveredHistoryView({
    super.key,
    required this.orders,
    required this.onRefresh,
    required this.unreadNotificationCount,
    required this.onNotificationsPressed,
    this.totals,
    this.hasNext = false,
    this.loadingMore = false,
    this.error,
    this.onLoadMore,
  });

  final List<CourierOrder> orders;
  final Future<void> Function() onRefresh;
  final int unreadNotificationCount;
  final VoidCallback onNotificationsPressed;
  final CourierOrderTotals? totals;
  final bool hasNext;
  final bool loadingMore;
  final String? error;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount:
            (orders.isEmpty ? 3 : orders.length + 2) +
            (hasNext || error != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          Widget content;
          if (index == 0) {
            content = PageTopBar(
              title: DeliveredTexts.title,
              subtitle: DeliveredTexts.subtitle,
              actions: [
                CourierNotificationsButton(
                  unreadCount: unreadNotificationCount,
                  onPressed: onNotificationsPressed,
                ),
              ],
            );
          } else if (index == 1) {
            content = _HistorySummary(orders: orders, totals: totals);
          } else if (index == (orders.isEmpty ? 3 : orders.length + 2)) {
            content = Column(
              children: [
                if (error != null) Text(error!),
                TextButton(
                  onPressed: loadingMore
                      ? null
                      : (hasNext ? onLoadMore : onRefresh),
                  child: Text(
                    loadingMore
                        ? DeliveredTexts.loading
                        : DeliveredTexts.loadMore,
                  ),
                ),
              ],
            );
          } else if (orders.isEmpty) {
            content = const _EmptyHistoryState();
          } else {
            final order = orders[index - 2];
            content = OrderCard(
              order: order,
              showDeliveredMeta: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailsView(order: order),
                  ),
                );
              },
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: content,
            ),
          );
        },
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.orders, this.totals});

  final List<CourierOrder> orders;
  final CourierOrderTotals? totals;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalValue =
        totals?.value ??
        orders.fold<double>(0, (total, order) => total + order.total);
    final totalDeliveryFees =
        totals?.deliveryFees ??
        orders.fold<double>(
          0,
          (total, order) => total + (order.deliveryPrice ?? 0),
        );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardColor
            : AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.success.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          _SummaryPill(
            icon: AppIcons.tick_circle,
            value: '${totals?.count ?? orders.length}',
            label: DeliveredTexts.deliveredOrder,
            color: AppColors.success,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            icon: AppIcons.money_3,
            value: AppCurrency.format(totalValue),
            label: DeliveredTexts.totalValue,
            color: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            icon: AppIcons.truck_fast,
            value: AppCurrency.format(totalDeliveryFees),
            label: DeliveredTexts.deliveryFees,
            color: AppColors.info,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.13 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(AppIcons.document_text, size: 30, color: iconColor),
          const SizedBox(height: 10),
          Text(
            DeliveredTexts.empty,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
