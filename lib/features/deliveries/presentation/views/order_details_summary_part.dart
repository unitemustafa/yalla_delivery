part of 'order_details_view.dart';

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: OrderDetailsTexts.summaryTitle,
      children: [
        _DetailRow(
          icon: AppIcons.receipt_text,
          label: OrderDetailsTexts.paymentMethod,
          value: _paymentMethodLabel(order.paymentMethod),
          mutedColor: mutedColor,
        ),
        if (order.shippingCompanyName != null)
          _DetailRow(
            icon: AppIcons.truck_fast,
            label: OrderDetailsTexts.shippingCompany,
            value: order.shippingCompanyName!,
            mutedColor: mutedColor,
          ),
        if (order.deliveryType != null)
          _DetailRow(
            icon: AppIcons.location,
            label: OrderDetailsTexts.pricingType,
            value: order.deliveryType == 'fixed_area'
                ? OrderDetailsTexts.fixedAreaPrice
                : OrderDetailsTexts.orderDeliveryPrice,
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.money_3,
          label: OrderDetailsTexts.products,
          value: AppCurrency.format(order.subtotal ?? order.total),
          mutedColor: mutedColor,
        ),
        _DetailRow(
          icon: AppIcons.truck_fast,
          label: OrderDetailsTexts.delivery,
          value: order.deliveryPrice == null
              ? CommonTexts.unspecified
              : AppCurrency.format(order.deliveryPrice!),
          mutedColor: mutedColor,
        ),
        if ((order.discount ?? 0) > 0)
          _DetailRow(
            icon: AppIcons.receipt_text,
            label: OrderDetailsTexts.discount,
            value: '- ${AppCurrency.format(order.discount!)}',
            mutedColor: mutedColor,
          ),
        if ((order.multiMarketFee ?? 0) > 0)
          _DetailRow(
            icon: AppIcons.shopping_bag,
            label: OrderDetailsTexts.multiMarketFee,
            value: AppCurrency.format(order.multiMarketFee!),
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.money_3,
          label: OrderDetailsTexts.total,
          value: AppCurrency.format(order.total),
          mutedColor: mutedColor,
        ),
        if (order.etaMinMinutes != null)
          _DetailRow(
            icon: AppIcons.calendar,
            label: OrderDetailsTexts.expectedDuration,
            value:
                order.etaMaxMinutes == null ||
                    order.etaMaxMinutes == order.etaMinMinutes
                ? TimeTexts.minutes(order.etaMinMinutes!)
                : TimeTexts.minuteRange(
                    order.etaMinMinutes!,
                    order.etaMaxMinutes!,
                  ),
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.calendar,
          label: OrderDetailsTexts.orderTime,
          value: _formatOrderDateTime(order.createdAt),
          mutedColor: mutedColor,
        ),
      ],
    );
  }

  static String _paymentMethodLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'cash' || 'cash_on_delivery' => OrderDetailsTexts.cashOnDelivery,
      'card' || 'credit_card' => OrdersTexts.card,
      'wallet' => OrderDetailsTexts.electronicWallet,
      final String value when value.isNotEmpty => value,
      _ => CommonTexts.unspecified,
    };
  }

  static String _formatOrderDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }
}
