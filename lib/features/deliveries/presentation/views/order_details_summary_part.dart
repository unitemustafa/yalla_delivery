part of 'order_details_view.dart';

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.mutedColor});

  final CourierOrder order;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'ملخص الطلب والدفع',
      children: [
        _DetailRow(
          icon: AppIcons.receipt_text,
          label: 'طريقة الدفع',
          value: _paymentMethodLabel(order.paymentMethod),
          mutedColor: mutedColor,
        ),
        if (order.shippingCompanyName != null)
          _DetailRow(
            icon: AppIcons.truck_fast,
            label: 'شركة الشحن',
            value: order.shippingCompanyName!,
            mutedColor: mutedColor,
          ),
        if (order.fulfillmentType != null)
          _DetailRow(
            icon: AppIcons.routing,
            label: 'مسار التنفيذ',
            value: order.fulfillmentType == 'direct'
                ? 'توصيل مباشر'
                : 'شحن خارجي',
            mutedColor: mutedColor,
          ),
        if (order.deliveryType != null)
          _DetailRow(
            icon: AppIcons.location,
            label: 'نوع التسعير',
            value: order.deliveryType == 'fixed_area'
                ? 'سعر منطقة ثابت'
                : 'سعر توصيل محدد للطلب',
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.money_3,
          label: 'المنتجات',
          value: AppCurrency.format(order.subtotal ?? order.total),
          mutedColor: mutedColor,
        ),
        _DetailRow(
          icon: AppIcons.truck_fast,
          label: 'التوصيل',
          value: order.deliveryPrice == null
              ? 'غير محدد'
              : AppCurrency.format(order.deliveryPrice!),
          mutedColor: mutedColor,
        ),
        if ((order.discount ?? 0) > 0)
          _DetailRow(
            icon: AppIcons.receipt_text,
            label: 'الخصم',
            value: '- ${AppCurrency.format(order.discount!)}',
            mutedColor: mutedColor,
          ),
        if ((order.multiMarketFee ?? 0) > 0)
          _DetailRow(
            icon: AppIcons.shopping_bag,
            label: 'رسوم تعدد المحلات',
            value: AppCurrency.format(order.multiMarketFee!),
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.money_3,
          label: 'الإجمالي',
          value: AppCurrency.format(order.total),
          mutedColor: mutedColor,
        ),
        if (order.etaMinMinutes != null)
          _DetailRow(
            icon: AppIcons.calendar,
            label: 'المدة المتوقعة',
            value:
                order.etaMaxMinutes == null ||
                    order.etaMaxMinutes == order.etaMinMinutes
                ? '${order.etaMinMinutes} دقيقة'
                : '${order.etaMinMinutes} - ${order.etaMaxMinutes} دقيقة',
            mutedColor: mutedColor,
          ),
        _DetailRow(
          icon: AppIcons.calendar,
          label: 'وقت الطلب',
          value: _formatOrderDateTime(order.createdAt),
          mutedColor: mutedColor,
        ),
      ],
    );
  }

  static String _paymentMethodLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'cash' || 'cash_on_delivery' => 'الدفع عند الاستلام',
      'card' || 'credit_card' => 'بطاقة',
      'wallet' => 'محفظة إلكترونية',
      final String value when value.isNotEmpty => value,
      _ => 'غير محدد',
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
