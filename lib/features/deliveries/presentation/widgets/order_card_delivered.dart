part of 'order_card.dart';

// ---------------------------------------------------------------------------
// Delivered order card (compact)
// ---------------------------------------------------------------------------

class _DeliveredOrderCard extends StatelessWidget {
  const _DeliveredOrderCard({required this.order, required this.onTap});

  final CourierOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? AppColors.success.withValues(alpha: 0.22)
        : AppColors.success.withValues(alpha: 0.14);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.54);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: Radius.circular(10),
                      bottomStart: Radius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DeliveredHeader(
                          deliveredAt: order.deliveredAt,
                          isDark: isDark,
                          mutedColor: mutedColor,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.shopping_bag,
                                    size: 12,
                                    color: mutedColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      order.marketName.isNotEmpty
                                          ? order.marketName
                                          : order.marketSummary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: mutedColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              AppIcons.location,
                              size: 13,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DeliveredMetaRow(order: order, isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveredHeader extends StatelessWidget {
  const _DeliveredHeader({
    required this.deliveredAt,
    required this.isDark,
    required this.mutedColor,
  });

  final DateTime? deliveredAt;
  final bool isDark;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.tick_circle, color: AppColors.success, size: 13),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'تم التسليم',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (deliveredAt != null) ...[
          const SizedBox(width: 6),
          Icon(AppIcons.calendar, size: 12, color: mutedColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _formatDeliveredTime(deliveredAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDeliveredTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$hour:$minute  $day/$month';
  }
}

class _DeliveredMetaRow extends StatelessWidget {
  const _DeliveredMetaRow({required this.order, required this.isDark});

  final CourierOrder order;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final chevronColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.28);

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _OrderChip(
                icon: AppIcons.money_3,
                value: AppCurrency.format(order.total),
                color: AppColors.success,
                isDark: isDark,
                isCompact: true,
              ),
              _OrderChip(
                icon: AppIcons.shopping_bag,
                value: '${order.itemCount}',
                color: AppColors.success,
                isDark: isDark,
                isCompact: true,
              ),
              if (order.deliveryPrice != null && order.deliveryPrice! > 0)
                _OrderChip(
                  icon: AppIcons.truck_fast,
                  value: AppCurrency.format(order.deliveryPrice!),
                  color: AppColors.success,
                  isDark: isDark,
                  isCompact: true,
                ),
            ],
          ),
        ),
        Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          size: 18,
          color: chevronColor,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chips & widgets
// ---------------------------------------------------------------------------

class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.icon,
    required this.value,
    required this.color,
    required this.isDark,
    this.isCompact = false,
  });

  final IconData icon;
  final String value;
  final Color color;
  final bool isDark;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 8,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isDark});

  final CourierOrderStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: isDark ? 0.22 : 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
