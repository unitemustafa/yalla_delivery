part of 'order_details_view.dart';

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
      title: OrderDetailsTexts.products,
      children: [
        if (total > 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  OrderDetailsTexts.pickedUpMarkets(pickedUp, total),
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
            OrderDetailsTexts.noProducts,
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
                    OrderStatusTexts.pickedUp,
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
                OrderDetailsTexts.noMarketProducts,
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
              label: const Text(OrderDetailsTexts.confirmMarketPickup),
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
              fit: BoxFit.contain,
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
                        OrderDetailsTexts.marketLine(
                          item.marketName ?? CommonTexts.unspecified,
                        ),
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
                if (item.additions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    OrderDetailsTexts.additions(
                      item.additions.join(CommonTexts.listSeparator),
                    ),
                  ),
                ],
                if (item.sku != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    OrderDetailsTexts.sku(item.sku!),
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
              fit: BoxFit.contain,
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
      title: OrderDetailsTexts.attachedPhoto,
      children: [
        Text(
          OrderDetailsTexts.customerPhotoDescription,
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
            semanticLabel: OrderDetailsTexts.customerOrderPhoto,
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
      title: OrderDetailsTexts.deliveryProof,
      children: [
        _DetailRow(
          icon: AppIcons.calendar,
          label: OrderDetailsTexts.deliveryTime,
          value: _formatDateTime(order.deliveredAt),
          mutedColor: mutedColor,
        ),
        if (order.deliveryNote != null)
          _DetailRow(
            icon: AppIcons.document_text,
            label: OrderDetailsTexts.note,
            value: order.deliveryNote!,
            mutedColor: mutedColor,
          ),
        if (proof == null && proofUrl == null)
          Text(
            OrderDetailsTexts.noUploadedPhoto,
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
              semanticLabel: OrderDetailsTexts.deliveryProofPhoto,
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
