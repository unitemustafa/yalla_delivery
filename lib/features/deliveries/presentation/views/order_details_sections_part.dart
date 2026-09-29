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
              child: const Text('إعادة المحاولة'),
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
              ? 'استلم منتجات كل المحلات أولًا'
              : order.hasPerMarketPickup
              ? 'تأكيد استلام الطلب'
              : 'تم الاستلام',
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
          label: 'تم التسليم',
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
    final date = value == null ? 'غير متاح' : _formatArabicDate(value);

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
                'وقت التسليم',
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
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${value.day} ${months[value.month - 1]}';
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
        semanticLabel: 'صورة العميل',
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
    CustomSnackBar.showSuccess(context: context, title: 'تم نسخ $label');
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
                        'العنوان',
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
                          title: 'تم نسخ العنوان',
                        );
                      },
                      icon: const Icon(AppIcons.copy, size: 17),
                      tooltip: 'نسخ العنوان',
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

class _ProductsByMarket extends StatelessWidget {
  const _ProductsByMarket({
    required this.order,
    required this.mutedColor,
    required this.pickingUpSectionId,
    required this.isUpdatingOrder,
    required this.onMarketPickupPressed,
  });

  final CourierOrder order;
  final Color mutedColor;
  final int? pickingUpSectionId;
  final bool isUpdatingOrder;
  final ValueChanged<int> onMarketPickupPressed;

  @override
  Widget build(BuildContext context) {
    final groups = order.productGroups;
    final total = order.totalMarketCount;
    final pickedUp = order.pickedUpMarketCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: 'المنتجات',
      children: [
        if (total > 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'تم استلام منتجات $pickedUp من $total محلات',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: pickedUp == total ? AppColors.success : mutedColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$pickedUp/$total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: pickedUp == total
                      ? AppColors.success
                      : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pickedUp / total,
            minHeight: 5,
            borderRadius: BorderRadius.circular(5),
            color: pickedUp == total ? AppColors.success : AppColors.primary,
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 16),
        ],
        if (groups.isEmpty)
          Text(
            'لا توجد منتجات في هذا الطلب.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        for (final group in groups) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: group.isPickedUp
                  ? AppColors.success.withValues(alpha: isDark ? 0.13 : 0.07)
                  : AppColors.primary.withValues(alpha: isDark ? 0.13 : 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  group.isPickedUp
                      ? AppIcons.tick_circle
                      : AppIcons.shopping_bag,
                  size: 18,
                  color: group.isPickedUp
                      ? AppColors.success
                      : AppColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    group.marketName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (group.isPickedUp)
                  Text(
                    'تم الاستلام',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (group.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'لا توجد منتجات لهذا المحل.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ),
          for (final item in group.items) _ProductRow(item: item),
          if (order.hasPerMarketPickup &&
              order.canMarkPickedUp &&
              !group.isPickedUp &&
              group.sectionId != null) ...[
            OutlinedButton.icon(
              key: ValueKey('market-pickup-${group.sectionId}'),
              onPressed: !isUpdatingOrder && pickingUpSectionId == null
                  ? () => onMarketPickupPressed(group.sectionId!)
                  : null,
              icon: pickingUpSectionId == group.sectionId
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.tick_circle, size: 17),
              label: const Text('تأكيد استلام منتجات المحل'),
            ),
            const SizedBox(height: 8),
          ],
          if (group != groups.last) ...[
            const SizedBox(height: 4),
            Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item});

  final CourierOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NetworkImageOrPlaceholder(
              url: item.imageUrl,
              placeholderAsset: AppAssets.defaultProduct,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              semanticLabel: item.name,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      AppIcons.shopping_bag,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'المحل: ${item.marketName ?? 'غير محدد'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.sku != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${item.sku}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (item.description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'x${item.quantity}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppCurrency.format(item.total),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                AppCurrency.format(item.price),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});

  final CourierOrderOffer offer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NetworkImageOrPlaceholder(
              url: offer.imageUrl,
              placeholderAsset: AppAssets.defaultProduct,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              semanticLabel: offer.title,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (offer.description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    offer.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (offer.discount != null && offer.discount! > 0)
            Text(
              '${offer.discount!.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRequestImageCard extends StatelessWidget {
  const _OrderRequestImageCard({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'صورة مرفقة بالطلب',
      children: [
        Text(
          'الصورة التي أرسلها العميل مع تفاصيل الطلب.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AuthenticatedNetworkImage(
            url: order.orderImageUrl,
            placeholderAsset: AppAssets.defaultProduct,
            width: double.infinity,
            height: 210,
            fit: BoxFit.contain,
            semanticLabel: 'صورة الطلب المرسلة من العميل',
          ),
        ),
      ],
    );
  }
}

class _DeliveryProofCard extends StatelessWidget {
  const _DeliveryProofCard({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final proof = order.deliveryProof;
    final proofUrl = order.deliveryProofUrl;

    return _SectionCard(
      title: 'إثبات التسليم',
      children: [
        _DetailRow(
          icon: AppIcons.calendar,
          label: 'وقت التسليم',
          value: _formatDateTime(order.deliveredAt),
          mutedColor: mutedColor,
        ),
        if (order.deliveryNote != null)
          _DetailRow(
            icon: AppIcons.document_text,
            label: 'ملاحظة',
            value: order.deliveryNote!,
            mutedColor: mutedColor,
          ),
        if (proof == null && proofUrl == null)
          Text(
            'لا توجد صورة مرفوعة.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          )
        else if (proofUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AuthenticatedNetworkImage(
              url: proofUrl,
              placeholderAsset: AppAssets.defaultProduct,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
              semanticLabel: 'صورة إثبات التسليم',
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              proof!.bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '---';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
