import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/formatters/app_time_ago.dart';
import '../../../../core/icons/app_icons.dart';
import '../../domain/courier_order.dart';
import '../extensions/courier_order_status_presentation.dart';

part 'order_card_active.dart';
part 'order_card_delivered.dart';

/// A card that displays a courier order summary.
///
/// When [showDeliveredMeta] is `true`, the card uses a compact, delivered-order
/// layout that emphasizes delivery time and area rather than the full address.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showDeliveredMeta = false,
  });

  final CourierOrder order;
  final VoidCallback onTap;
  final bool showDeliveredMeta;

  @override
  Widget build(BuildContext context) {
    return showDeliveredMeta
        ? _DeliveredOrderCard(order: order, onTap: onTap)
        : _ActiveOrderCard(order: order, onTap: onTap);
  }
}
