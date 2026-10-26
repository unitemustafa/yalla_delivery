import 'courier_notification.dart';

class CourierNotificationPage {
  const CourierNotificationPage({
    required this.items,
    required this.count,
    required this.unreadCount,
    required this.hasNext,
  });
  final List<CourierNotification> items;
  final int count;
  final int unreadCount;
  final bool hasNext;
}
