import '../../../core/domain/api_result.dart';
import 'courier_notification.dart';
import 'courier_notification_page.dart';
import 'courier_notifications_repository.dart';

class CourierNotificationsUseCases {
  CourierNotificationsUseCases(CourierNotificationsRepository repository)
    : load = LoadCourierNotifications(repository),
      unread = LoadCourierUnreadCount(repository),
      read = ReadCourierNotification(repository),
      readAll = ReadAllCourierNotifications(repository),
      delete = DeleteCourierNotification(repository);
  final LoadCourierNotifications load;
  final LoadCourierUnreadCount unread;
  final ReadCourierNotification read;
  final ReadAllCourierNotifications readAll;
  final DeleteCourierNotification delete;
}

class LoadCourierNotifications {
  const LoadCourierNotifications(this._repository);
  final CourierNotificationsRepository _repository;
  Future<ApiResult<CourierNotificationPage>> call({int page = 1}) =>
      _repository.loadPage(page: page);
}

class LoadCourierUnreadCount {
  const LoadCourierUnreadCount(this._repository);
  final CourierNotificationsRepository _repository;
  Future<ApiResult<int>> call() => _repository.unreadCount();
}

class ReadCourierNotification {
  const ReadCourierNotification(this._repository);
  final CourierNotificationsRepository _repository;
  Future<ApiResult<CourierNotification>> call(CourierNotification item) =>
      _repository.markRead(item);
}

class ReadAllCourierNotifications {
  const ReadAllCourierNotifications(this._repository);
  final CourierNotificationsRepository _repository;
  Future<ApiResult<int>> call() => _repository.markAllRead();
}

class DeleteCourierNotification {
  const DeleteCourierNotification(this._repository);
  final CourierNotificationsRepository _repository;
  Future<ApiResult<void>> call(String id) => _repository.delete(id);
}
