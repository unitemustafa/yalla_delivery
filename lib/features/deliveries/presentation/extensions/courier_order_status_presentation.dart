import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/texts/app_texts.dart';
import '../../../../core/icons/app_icons.dart';
import '../../domain/courier_order.dart';

extension CourierOrderStatusPresentation on CourierOrderStatus {
  String get label {
    return switch (this) {
      CourierOrderStatus.pending => OrderStatusTexts.pending,
      CourierOrderStatus.confirmed => OrderStatusTexts.confirmed,
      CourierOrderStatus.assigned => OrderStatusTexts.assigned,
      CourierOrderStatus.pickedUp => OrderStatusTexts.pickedUp,
      CourierOrderStatus.delivered => OrderStatusTexts.delivered,
      CourierOrderStatus.failedDelivery => OrderStatusTexts.failedDelivery,
      CourierOrderStatus.cancelled => OrderStatusTexts.cancelled,
      CourierOrderStatus.unknown => OrderStatusTexts.unknown,
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
