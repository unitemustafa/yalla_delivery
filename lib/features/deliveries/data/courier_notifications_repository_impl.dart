import '../../../core/domain/api_result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/texts/app_texts.dart';
import '../domain/courier_notification.dart';
import '../domain/courier_notification_page.dart';
import '../domain/courier_notifications_repository.dart';
import 'courier_notifications_api.dart';

class CourierNotificationsRepositoryImpl
    implements CourierNotificationsRepository {
  const CourierNotificationsRepositoryImpl(this._api);
  final CourierNotificationsApi _api;
  Future<ApiResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return ApiSuccess(await action());
    } on ApiException catch (error) {
      return ApiFailure(
        error.statusCode == null
            ? ApiFailureReason.network
            : ApiFailureReason.server,
        message: error.message,
      );
    } on FormatException {
      return const ApiFailure(
        ApiFailureReason.invalidResponse,
        message: NotificationTexts.loadFailedRetry,
      );
    } catch (_) {
      return const ApiFailure(
        ApiFailureReason.network,
        message: CommonTexts.connectionFailed,
      );
    }
  }

  @override
  Future<ApiResult<CourierNotificationPage>> loadPage({int page = 1}) =>
      _guard(() => _api.loadPage(page: page));
  @override
  Future<ApiResult<int>> unreadCount() => _guard(_api.loadUnreadCount);
  @override
  Future<ApiResult<CourierNotification>> markRead(CourierNotification item) =>
      _guard(() => _api.markRead(item.id, current: item));
  @override
  Future<ApiResult<int>> markAllRead() => _guard(_api.markAllRead);
  @override
  Future<ApiResult<void>> delete(String id) =>
      _guard(() => _api.deleteNotification(id));
}
