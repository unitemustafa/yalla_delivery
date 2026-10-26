import '../../../core/domain/api_result.dart';
import 'courier_notification.dart';
import 'courier_notification_page.dart';

abstract interface class CourierNotificationsRepository {
  Future<ApiResult<CourierNotificationPage>> loadPage({int page = 1});
  Future<ApiResult<int>> unreadCount();
  Future<ApiResult<CourierNotification>> markRead(CourierNotification item);
  Future<ApiResult<int>> markAllRead();
  Future<ApiResult<void>> delete(String id);
}
