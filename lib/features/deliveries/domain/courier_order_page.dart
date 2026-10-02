import 'courier_order.dart';

class CourierOrderTotals {
  const CourierOrderTotals({
    required this.count,
    required this.value,
    required this.deliveryFees,
  });
  final int count;
  final double value;
  final double deliveryFees;
}

class CourierOrderPage {
  const CourierOrderPage({
    required this.orders,
    required this.hasNext,
    required this.totals,
  });
  final List<CourierOrder> orders;
  final bool hasNext;
  final CourierOrderTotals totals;
}
