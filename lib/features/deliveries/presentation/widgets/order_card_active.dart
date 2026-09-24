part of 'order_card.dart';

// ---------------------------------------------------------------------------
// Active order card
// ---------------------------------------------------------------------------

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order, required this.onTap});

  final CourierOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = order.status.color;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? statusColor.withValues(alpha: 0.28)
        : statusColor.withValues(alpha: 0.18);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.54);
    final tintColor = statusColor.withValues(alpha: isDark ? 0.10 : 0.04);
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    final notes = order.customerNotes?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tintColor, panelColor, panelColor],
              stops: const [0, 0.40, 1],
            ),
            boxShadow: shadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4.5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: Radius.circular(12),
                      bottomStart: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 13, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActiveHeader(order: order, isDark: isDark),
                        const SizedBox(height: 10),
                        _CustomerRow(order: order, mutedColor: mutedColor),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              AppIcons.location,
                              size: 14,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                order.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _CustomerNotesRow(notes: notes, isDark: isDark),
                        ],
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        const SizedBox(height: 10),
                        _ActiveMetaRow(order: order, isDark: isDark),
                        const SizedBox(height: 8),
                        _TimeAgoRow(
                          createdAt: order.assignedAt ?? order.createdAt,
                          mutedColor: mutedColor,
                        ),
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

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({required this.order, required this.isDark});

  final CourierOrder order;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.54);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: order.status.color.withValues(alpha: isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(order.status.icon, color: order.status.color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.marketSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (order.marketCount > 1)
                Text(
                  '${order.marketCount} محلات',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: order.status.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusChip(status: order.status, isDark: isDark),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            order.customerName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '#${order.id}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CustomerNotesRow extends StatelessWidget {
  const _CustomerNotesRow({required this.notes, required this.isDark});

  final String notes;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final noteColor = isDark ? AppColors.warning : const Color(0xFFB45309);
    final bgColor = AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.07);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(AppIcons.document_text, size: 13, color: noteColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              notes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: noteColor,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMetaRow extends StatelessWidget {
  const _ActiveMetaRow({required this.order, required this.isDark});

  final CourierOrder order;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final payment = order.paymentMethod?.trim();
    final chips = <Widget>[
      _OrderChip(
        icon: AppIcons.money_3,
        value: AppCurrency.format(order.total),
        color: order.status.color,
        isDark: isDark,
      ),
      _OrderChip(
        icon: AppIcons.shopping_bag,
        value: '${order.itemCount} منتج',
        color: order.status.color,
        isDark: isDark,
      ),
      if (payment != null && payment.isNotEmpty)
        _OrderChip(
          icon: AppIcons.receipt_text,
          value: _paymentLabel(payment),
          color: order.status.color,
          isDark: isDark,
        ),
    ];

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  static String _paymentLabel(String method) {
    return switch (method.toLowerCase()) {
      'cash' || 'cod' => 'كاش',
      'card' || 'credit_card' || 'visa' => 'بطاقة',
      'wallet' || 'e_wallet' => 'محفظة',
      'online' => 'أونلاين',
      _ => method,
    };
  }
}

class _TimeAgoRow extends StatelessWidget {
  const _TimeAgoRow({required this.createdAt, required this.mutedColor});

  final DateTime createdAt;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        Icon(AppIcons.calendar, size: 13, color: mutedColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            AppTimeAgo.format(createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Icon(
          isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          size: 20,
          color: mutedColor,
        ),
      ],
    );
  }
}
