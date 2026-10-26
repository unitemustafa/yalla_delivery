import '../../../core/auth/auth_session.dart';
import '../domain/courier_notification.dart';
import '../domain/courier_notification_page.dart';

class CourierNotificationsApi {
  const CourierNotificationsApi({AuthSession? session}) : _session = session;
  final AuthSession? _session;
  AuthSession get session => _session ?? AuthSession.instance;

  Future<CourierNotificationPage> loadPage({int page = 1}) async {
    if (page < 1) throw const FormatException('Invalid page.');
    final data = await session.getJson(
      'notifications/?page=$page&page_size=30',
    );
    if (data is! Map ||
        data['results'] is! List ||
        data['count'] is! int ||
        data['unread_count'] is! int ||
        (data['count'] as int) < 0 ||
        (data['unread_count'] as int) < 0 ||
        (data['results'] as List).length > 30) {
      throw const FormatException('Invalid notification page.');
    }
    final items = parseNotificationsResponse(data);
    if (items.length != (data['results'] as List).length ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw const FormatException('Invalid notification rows.');
    }
    return CourierNotificationPage(
      items: List.unmodifiable(items),
      count: data['count'] as int,
      unreadCount: data['unread_count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<List<CourierNotification>> loadNotifications() async {
    final data = await session.getJson('notifications/');
    return parseNotificationsResponse(data);
  }

  Future<int> loadUnreadCount() async {
    final data = await session.getJson('notifications/unread-count/');
    return parseUnreadCountResponse(data);
  }

  Future<CourierNotification> markRead(
    String notificationId, {
    CourierNotification? current,
  }) async {
    final data = await session.patchJson(
      'notifications/$notificationId/read/',
      const <String, dynamic>{},
    );
    if (data is Map) {
      return CourierNotification.fromJson(Map<String, dynamic>.from(data));
    }
    if (current != null) return current.copyWith(isRead: true);
    return CourierNotification(
      id: notificationId,
      audience: '',
      type: '',
      title: '',
      message: '',
      isRead: true,
      isBlocking: false,
      isResolved: false,
      createdAt: DateTime.now(),
    );
  }

  Future<int> markAllRead() async {
    final data = await session.postJson(
      'notifications/mark-all-read/',
      const <String, dynamic>{},
    );
    if (data is Map) {
      return _int(data['marked_read'] ?? data['markedRead']);
    }
    return 0;
  }

  Future<void> deleteNotification(String notificationId) async {
    await session.deleteJson('notifications/$notificationId/');
  }

  static List<CourierNotification> parseNotificationsResponse(dynamic data) {
    final rows = data is Map ? data['results'] : data;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (item) =>
              CourierNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((notification) => notification.id.isNotEmpty)
        .toList(growable: false);
  }

  static int parseUnreadCountResponse(dynamic data) {
    if (data is Map) {
      return _int(data['unread_count'] ?? data['unreadCount'] ?? data['count']);
    }
    return _int(data);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
