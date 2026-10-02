import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_session.dart';
import '../routing/app_navigator.dart';
import '../network/api_exception.dart';

const courierOrdersChannelId = 'courier_orders';
const accountUpdatesChannelId = 'account_updates';
const courierUpdatesChannelId = 'courier_updates';

@pragma('vm:entry-point')
Future<void> courierFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class CourierPushEvent {
  const CourierPushEvent(this.data, {required this.opened});
  final Map<String, dynamic> data;
  final bool opened;
  String get event => data['event']?.toString() ?? '';

  String get title {
    final remoteTitle = data['_title']?.toString().trim() ?? '';
    if (remoteTitle.isNotEmpty) return remoteTitle;
    return switch (event) {
      'courier_order_assigned' => 'طلب توصيل جديد',
      'courier_order_unassigned' => 'تم سحب طلب',
      'courier_order_cancelled' => 'تم إلغاء طلب',
      'courier_account_restored' => 'تم استعادة حسابك',
      'courier_profile_updated' => 'تم تحديث بيانات حسابك',
      'courier_availability_changed' => 'تحديث حالة استقبال الطلبات',
      _ => 'تحديث من يلا ماركت',
    };
  }

  String get body {
    final remoteBody = data['_body']?.toString().trim() ?? '';
    if (remoteBody.isNotEmpty) return remoteBody;
    final number = data['order_number'] ?? data['order_id'] ?? '';
    return switch (event) {
      'courier_order_assigned' =>
        'تم تعيين الطلب #$number لك. اضغط لعرض التفاصيل.',
      'courier_order_unassigned' => 'تم سحب الطلب #$number من قائمة مهامك.',
      'courier_order_cancelled' => 'تم إلغاء الطلب #$number.',
      'courier_account_restored' =>
        'تم استعادة حساب الطيار بواسطة فريق دعم يلا ماركت.',
      'courier_profile_updated' => 'تم تحديث بيانات الطيار.',
      'courier_availability_changed' => 'تم تحديث حالة استقبال الطلبات.',
      _ => 'تم تحديث بيانات حساب الطيار.',
    };
  }
}

class CourierPushService {
  CourierPushService._();
  static final instance = CourierPushService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _events = StreamController<CourierPushEvent>.broadcast();
  final List<CourierPushEvent> _pendingOpenedEvents = [];
  final Map<String, DateTime> _handled = {};
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Future<bool>? _initialization;
  bool _firebaseReady = false;
  bool _permissionRequested = false;
  bool _disablingAccount = false;
  bool _routingReady = false;
  int? _boundVersion;
  String? _registeredToken;
  Future<void>? _registration;
  Timer? _registrationRetry;
  int _retryAttempt = 0;
  Future<void> Function(Map<String, dynamic>)? _localShowOverride;

  Stream<CourierPushEvent> get events => _events.stream;

  @visibleForTesting
  set localShowOverrideForTesting(
    Future<void> Function(Map<String, dynamic>)? callback,
  ) => _localShowOverride = callback;

  List<CourierPushEvent> takePendingOpenedEvents() {
    final currentId = AuthSession.instance.currentUser?['id'];
    final pending = _pendingOpenedEvents.where((event) {
      final recipient = event.data['recipient_id'] ?? event.data['courier_id'];
      return currentId != null &&
          (recipient == null || recipient.toString() == currentId.toString());
    }).toList();
    _pendingOpenedEvents.clear();
    return pending;
  }

  void attachOpenedEventRouter() => _routingReady = true;
  void detachOpenedEventRouter() => _routingReady = false;

  Future<void> retryRegistrationOnResume() {
    _retryAttempt = 0;
    return registerAuthenticatedDevice();
  }

  Future<bool> initialize() async {
    AuthSession.instance.beforeLogout = unregisterAuthenticatedDevice;
    AuthSession.instance.onSessionCleared = clearSessionNotifications;
    final pending = _initialization ??= _initialize();
    final ready = await pending;
    if (!ready && identical(_initialization, pending)) _initialization = null;
    return ready;
  }

  Future<bool> _initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(courierFirebaseBackgroundHandler);
      await Firebase.initializeApp();
      await _initializeLocalNotifications();
      await _foregroundSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _tokenSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_handle(message, opened: false)),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_handle(message, opened: true)),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => unawaited(_registerRefreshedToken()),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _handle(initial, opened: true);
      _firebaseReady = true;
      return true;
    } catch (error, stackTrace) {
      _debugFailure('initialization', error, stackTrace);
      _firebaseReady = false;
      return false;
    }
  }

  Future<void> registerAuthenticatedDevice() async {
    final active = _registration;
    if (active != null) return active;
    final operation = _performRegistration();
    _registration = operation;
    try {
      await operation;
    } finally {
      if (identical(_registration, operation)) _registration = null;
    }
  }

  Future<void> _registerRefreshedToken() async {
    final version = AuthSession.instance.sessionVersion;
    await _registration;
    if (version == AuthSession.instance.sessionVersion) {
      await registerAuthenticatedDevice();
    }
  }

  Future<void> _performRegistration() async {
    if (AuthSession.instance.currentUser?['role'] != 'representative') return;
    final version = AuthSession.instance.sessionVersion;
    try {
      if (!await initialize()) {
        _scheduleRegistrationRetry(version);
        return;
      }
      if (!await _ensureNotificationPermission()) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (version != AuthSession.instance.sessionVersion) return;
      if (token == null || token.isEmpty) {
        _scheduleRegistrationRetry(version);
        return;
      }
      await _registerToken(token, version);
      _retryAttempt = 0;
      _registrationRetry?.cancel();
    } catch (error, stackTrace) {
      _debugFailure('device registration', error, stackTrace);
      _scheduleRegistrationRetry(version);
    }
  }

  void _scheduleRegistrationRetry(int version) {
    if (version != AuthSession.instance.sessionVersion || _retryAttempt >= 3) {
      return;
    }
    _registrationRetry?.cancel();
    final seconds = [2, 10, 30][_retryAttempt++];
    _registrationRetry = Timer(Duration(seconds: seconds), () {
      if (version == AuthSession.instance.sessionVersion) {
        unawaited(registerAuthenticatedDevice());
      }
    });
  }

  Future<bool> _ensureNotificationPermission() async {
    if (!_firebaseReady || _permissionRequested) {
      if (!_firebaseReady) return false;
      final current = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _isNotificationPermissionGranted(current.authorizationStatus);
    }

    _permissionRequested = true;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return _isNotificationPermissionGranted(settings.authorizationStatus);
  }

  bool _isNotificationPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _registerToken(String token, int version) async {
    if (AuthSession.instance.currentUser?['role'] != 'representative') return;
    if (version != AuthSession.instance.sessionVersion) return;
    await AuthSession.instance.postJson('notifications/devices/register/', {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    });
    if (version != AuthSession.instance.sessionVersion) return;
    _registeredToken = token;
    _boundVersion = version;
    _disablingAccount = false;
  }

  Future<void> unregisterAuthenticatedDevice() async {
    _registrationRetry?.cancel();
    final version = AuthSession.instance.sessionVersion;
    try {
      final token =
          _registeredToken ??
          (_firebaseReady ? await FirebaseMessaging.instance.getToken() : null);
      if (token == null || version != AuthSession.instance.sessionVersion) {
        return;
      }
      await AuthSession.instance.deleteJson(
        'notifications/devices/unregister/',
        body: {'token': token},
      );
    } catch (error, stackTrace) {
      _debugFailure('device unregistration', error, stackTrace);
    }
  }

  Future<void> clearSessionNotifications() async {
    final version = AuthSession.instance.sessionVersion;
    _registrationRetry?.cancel();
    _retryAttempt = 0;
    _registration = null;
    _boundVersion = null;
    _registeredToken = null;
    _disablingAccount = false;
    _routingReady = false;
    _pendingOpenedEvents.clear();
    _handled.clear();
    try {
      await _local.cancelAll();
    } catch (error, stackTrace) {
      _debugFailure('local notification cleanup', error, stackTrace);
    }
    try {
      if (_firebaseReady && version == AuthSession.instance.sessionVersion) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (error, stackTrace) {
      _debugFailure('notification cleanup', error, stackTrace);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          unawaited(
            handleData(Map<String, dynamic>.from(decoded), opened: true),
          );
        }
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        courierOrdersChannelId,
        'طلبات التوصيل',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        accountUpdatesChannelId,
        'تحديثات الحساب',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        courierUpdatesChannelId,
        'تحديثات الطيار',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<void> _handle(RemoteMessage message, {required bool opened}) async {
    final data = Map<String, dynamic>.from(message.data);
    if (message.messageId != null) data['_message_id'] = message.messageId!;
    data['_title'] = message.notification?.title;
    data['_body'] = message.notification?.body;
    await handleData(data, opened: opened);
  }

  @visibleForTesting
  Future<void> handleData(
    Map<String, dynamic> data, {
    required bool opened,
  }) async {
    final event = data['event']?.toString() ?? '';
    final recipient = data['recipient_id'] ?? data['courier_id'];
    final currentId = AuthSession.instance.currentUser?['id'];
    final version = AuthSession.instance.sessionVersion;
    // Foreground events feed both OS notifications and in-app feedback. A
    // device token can outlive a login, so neither may reveal unverified data.
    // Legacy account-disable events are checked against the API below instead.
    if (!opened &&
        (AuthSession.instance.currentUser?['role'] != 'representative' ||
            currentId == null ||
            (recipient == null && event != 'courier_account_disabled'))) {
      return;
    }
    if (currentId != null &&
        recipient != null &&
        currentId.toString() != recipient.toString()) {
      return;
    }
    if (_boundVersion != null &&
        _boundVersion != AuthSession.instance.sessionVersion) {
      return;
    }
    if (event.isEmpty || !_accept(data, opened: opened)) return;
    if (event == 'courier_account_disabled') {
      if (currentId == null) return;
      // Old payloads have no recipient. Verify the active account on the API
      // before invalidating a potentially different user's session.
      if (recipient == null) {
        try {
          await AuthSession.instance.getJson('auth/me/');
          return;
        } on ApiException catch (error) {
          if (error.code != 'account_inactive') return;
        }
      }
      if (version != AuthSession.instance.sessionVersion) return;
      await _disableAccountOnce();
      return;
    }
    // A device may still receive a delayed message for a previous login.
    // Only addressed messages may display private notification content.
    if (!opened &&
        currentId != null &&
        recipient != null &&
        event != 'courier_profile_updated') {
      await _showLocal(data);
    }
    if (!opened &&
        (version != AuthSession.instance.sessionVersion ||
            AuthSession.instance.currentUser?['role'] != 'representative' ||
            AuthSession.instance.currentUser?['id']?.toString() !=
                currentId.toString())) {
      return;
    }
    final pushEvent = CourierPushEvent(data, opened: opened);
    if (opened && !_routingReady) {
      if (_pendingOpenedEvents.length >= 20) _pendingOpenedEvents.removeAt(0);
      _pendingOpenedEvents.add(pushEvent);
    } else {
      _events.add(pushEvent);
    }
  }

  bool _accept(Map<String, dynamic> data, {required bool opened}) {
    final now = DateTime.now();
    _handled.removeWhere(
      (_, at) => now.difference(at) > const Duration(minutes: 10),
    );
    while (_handled.length >= 100) {
      _handled.remove(_handled.keys.first);
    }
    final notificationId = data['notification_id']?.toString().trim();
    final phase = opened ? 'open' : 'display';
    final key = notificationId != null && notificationId.isNotEmpty
        ? '$phase:notification:$notificationId'
        : '$phase:${data['event']}:${data['order_id'] ?? ''}:${data['_message_id'] ?? ''}';
    return _handled.putIfAbsent(key, () => now) == now;
  }

  Future<void> _showLocal(Map<String, dynamic> data) async {
    final override = _localShowOverride;
    if (override != null) {
      await override(data);
      return;
    }
    final event = data['event']?.toString() ?? '';
    final channel = event.startsWith('courier_order_')
        ? courierOrdersChannelId
        : event.startsWith('courier_account_')
        ? accountUpdatesChannelId
        : courierUpdatesChannelId;
    final channelName = channel == courierOrdersChannelId
        ? 'طلبات التوصيل'
        : channel == accountUpdatesChannelId
        ? 'تحديثات الحساب'
        : 'تحديثات الطيار';
    final pushEvent = CourierPushEvent(data, opened: false);
    final title = pushEvent.title;
    final body = pushEvent.body;
    await _local.show(
      id:
          int.tryParse(data['notification_id']?.toString() ?? '') ??
          data.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          importance: channel == courierUpdatesChannelId
              ? Importance.defaultImportance
              : Importance.high,
          priority: channel == courierUpdatesChannelId
              ? Priority.defaultPriority
              : Priority.high,
          icon: 'ic_notification',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> _disableAccountOnce() async {
    if (_disablingAccount) return;
    _disablingAccount = true;
    final version = AuthSession.instance.sessionVersion;
    await AuthSession.instance.clear();
    if (AuthSession.instance.sessionVersion == version + 1 &&
        AuthSession.instance.currentUser == null) {
      AppNavigator.goToLogin();
    }
  }

  Future<void> dispose() async {
    _registrationRetry?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _events.close();
  }
}

void _debugFailure(String operation, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('Courier push $operation failed (${error.runtimeType}).');
}
