part of 'order_details_view.dart';

class _DetailRetryState extends StatelessWidget {
  const _DetailRetryState({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text(CommonTexts.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({
    required this.order,
    required this.submittingAction,
    required this.isPickingUpMarket,
    required this.onPickupPressed,
    required this.onDeliveryPressed,
  });

  final CourierOrder order;
  final _SubmittingOrderAction? submittingAction;
  final bool isPickingUpMarket;
  final VoidCallback onPickupPressed;
  final VoidCallback onDeliveryPressed;

  @override
  Widget build(BuildContext context) {
    final isUpdating = submittingAction != null || isPickingUpMarket;
    final pickupCompleted =
        order.status == CourierOrderStatus.pickedUp || order.isDelivered;

    return Column(
      children: [
        AppActionButton(
          label: order.hasPerMarketPickup && !order.canCompletePickup
              ? OrderDetailsTexts.pickupAllMarketsFirst
              : order.hasPerMarketPickup
              ? OrderDetailsTexts.confirmPickup
              : OrderStatusTexts.pickedUp,
          icon: pickupCompleted ? AppIcons.tick_circle : AppIcons.box,
          variant: pickupCompleted
              ? AppActionButtonVariant.outlined
              : AppActionButtonVariant.filled,
          isLoading: submittingAction == _SubmittingOrderAction.pickup,
          onPressed:
              !isUpdating && order.canMarkPickedUp && order.canCompletePickup
              ? onPickupPressed
              : null,
        ),
        const SizedBox(height: 10),
        AppActionButton(
          label: OrderStatusTexts.delivered,
          icon: AppIcons.tick_circle,
          isLoading: submittingAction == _SubmittingOrderAction.delivery,
          onPressed: !isUpdating && order.canMarkDelivered
              ? onDeliveryPressed
              : null,
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: order.status.color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(AppIcons.box, color: order.status.color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: order.status.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${order.area} • ${AppCurrency.format(order.total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (order.isDelivered)
            _DeliveredTimeBadge(
              value: order.deliveredAt,
              accentColor: order.status.color,
              mutedColor: mutedColor,
            ),
        ],
      ),
    );
  }
}

class _DeliveredTimeBadge extends StatelessWidget {
  const _DeliveredTimeBadge({
    required this.value,
    required this.accentColor,
    required this.mutedColor,
  });

  final DateTime? value;
  final Color accentColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final time = value == null ? '--:--' : _formatClock(value);
    final date = value == null
        ? CommonTexts.unavailable
        : _formatArabicDate(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.calendar, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                OrderDetailsTexts.deliveryTime,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              time,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatArabicDate(DateTime value) {
    return '${value.day} ${TimeTexts.months[value.month - 1]}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CustomerSummaryTile extends StatelessWidget {
  const _CustomerSummaryTile({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.045),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _CustomerAvatar(order: order, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      order.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.order, this.size = 46});

  final CourierOrder order;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = order.customerAvatarUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: NetworkImageOrPlaceholder(
        url: avatarUrl,
        placeholderAsset: AppAssets.defaultUserAvatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: OrderDetailsTexts.customerPhoto,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.mutedColor,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color mutedColor;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: copyable ? () => _copyValue(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: copyable ? 4 : 0,
              vertical: copyable ? 4 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: mutedColor),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.copy, size: 16, color: mutedColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    CustomSnackBar.showSuccess(
      context: context,
      title: CommonTexts.copied(label),
    );
  }
}

class _ExpandableAddressRow extends StatefulWidget {
  const _ExpandableAddressRow({required this.address});

  final String address;

  @override
  State<_ExpandableAddressRow> createState() => _ExpandableAddressRowState();
}

class _ExpandableAddressRowState extends State<_ExpandableAddressRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.58);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.045),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.location, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        OrderDetailsTexts.address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.address),
                        );
                        if (!context.mounted) return;
                        CustomSnackBar.showSuccess(
                          context: context,
                          title: OrderDetailsTexts.addressCopied,
                        );
                      },
                      icon: const Icon(AppIcons.copy, size: 17),
                      tooltip: OrderDetailsTexts.copyAddress,
                      visualDensity: VisualDensity.compact,
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: mutedColor,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: AlignmentDirectional.topStart,
                  child: Text(
                    widget.address,
                    maxLines: _expanded ? null : 1,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.4,
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
