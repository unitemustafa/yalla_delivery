import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../domain/courier_order.dart';

extension CourierOrderStatusPresentation on CourierOrderStatus {
  String get label {
    return switch (this) {
      CourierOrderStatus.pending => 'قيد الانتظار',
      CourierOrderStatus.confirmed => 'مؤكد',
      CourierOrderStatus.assigned => 'مطلوب الاستلام',
      CourierOrderStatus.pickedUp => 'تم الاستلام',
      CourierOrderStatus.delivered => 'تم التسليم',
      CourierOrderStatus.failedDelivery => 'تعذر التوصيل',
      CourierOrderStatus.cancelled => 'ملغي',
      CourierOrderStatus.unknown => 'حالة غير معروفة',
    };
  }

  Color get color {
    return switch (this) {
      CourierOrderStatus.pending => AppColors.warning,
      CourierOrderStatus.confirmed => AppColors.info,
      CourierOrderStatus.assigned => AppColors.info,
      CourierOrderStatus.pickedUp => AppColors.primary,
      CourierOrderStatus.delivered => AppColors.success,
      CourierOrderStatus.failedDelivery => AppColors.error,
      CourierOrderStatus.cancelled => AppColors.error,
      CourierOrderStatus.unknown => AppColors.lightTextSecondary,
    };
  }

  IconData get icon {
    return switch (this) {
      CourierOrderStatus.pending => AppIcons.receipt_text,
      CourierOrderStatus.confirmed => AppIcons.receipt_text,
      CourierOrderStatus.assigned => AppIcons.box,
      CourierOrderStatus.pickedUp => AppIcons.truck_fast,
      CourierOrderStatus.delivered => AppIcons.tick_circle,
      CourierOrderStatus.failedDelivery => AppIcons.danger,
      CourierOrderStatus.cancelled => AppIcons.danger,
      CourierOrderStatus.unknown => AppIcons.info_circle,
    };
  }
}
