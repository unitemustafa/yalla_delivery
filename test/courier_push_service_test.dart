import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/auth/auth_session.dart';
import 'package:yalla_home/core/notifications/courier_push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthSession.instance.currentUser = {'id': 99, 'role': 'representative'};
  });
  tearDown(() {
    CourierPushService.instance.localShowOverrideForTesting = null;
    AuthSession.instance.currentUser = null;
  });

  for (final event in ['courier_order_assigned', 'courier_account_restored']) {
    test('logged out foreground $event exposes no private feedback', () async {
      final service = CourierPushService.instance;
      AuthSession.instance.currentUser = null;
      var shown = 0;
      final received = <CourierPushEvent>[];
      service.localShowOverrideForTesting = (_) async => shown++;
      final subscription = service.events.listen(received.add);
      addTearDown(subscription.cancel);

      await service.handleData({
        'event': event,
        'recipient_id': 99,
        'notification_id': 'logged-out-$event',
        '_title': 'Private title',
        '_body': 'Private body',
      }, opened: false);
      await Future<void>.delayed(Duration.zero);

      expect(shown, 0);
      expect(received, isEmpty);
    });

    test('unaddressed foreground $event exposes no private feedback', () async {
      final service = CourierPushService.instance;
      var shown = 0;
      final received = <CourierPushEvent>[];
      service.localShowOverrideForTesting = (_) async => shown++;
      final subscription = service.events.listen(received.add);
      addTearDown(subscription.cancel);

      await service.handleData({
        'event': event,
        'notification_id': 'unaddressed-$event',
        '_title': 'Private title',
        '_body': 'Private body',
      }, opened: false);
      await Future<void>.delayed(Duration.zero);

      expect(shown, 0);
      expect(received, isEmpty);
    });
  }

  for (final replacementId in [99, 100]) {
    test(
      'foreground push cannot emit after session replacement by $replacementId',
      () async {
        final service = CourierPushService.instance;
        final started = Completer<void>();
        final shown = Completer<void>();
        final received = <CourierPushEvent>[];
        service.localShowOverrideForTesting = (_) {
          started.complete();
          return shown.future;
        };
        final subscription = service.events.listen(received.add);
        addTearDown(subscription.cancel);

        final handling = service.handleData({
          'event': 'courier_order_assigned',
          'recipient_id': 99,
          'notification_id': 'session-switched-during-show-$replacementId',
        }, opened: false);
        await started.future;
        await AuthSession.instance.clear();
        // A relogin into the same account is also a distinct session.
        AuthSession.instance.currentUser = {
          'id': replacementId,
          'role': 'representative',
        };
        shown.complete();
        await handling;
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
      },
    );
  }

  for (final user in [
    {'id': 100, 'role': 'representative'},
    {'id': 99, 'role': 'client'},
  ]) {
    test('foreground push requires matching representative $user', () async {
      final service = CourierPushService.instance;
      AuthSession.instance.currentUser = user;
      var shown = 0;
      final received = <CourierPushEvent>[];
      service.localShowOverrideForTesting = (_) async => shown++;
      final subscription = service.events.listen(received.add);
      addTearDown(subscription.cancel);

      await service.handleData({
        'event': 'courier_order_assigned',
        'recipient_id': 99,
        'notification_id': 'mismatched-$user',
      }, opened: false);
      await Future<void>.delayed(Duration.zero);

      expect(shown, 0);
      expect(received, isEmpty);
    });
  }

  test(
    'foreground push is displayed and emitted once per notification id',
    () async {
      final service = CourierPushService.instance;
      var shown = 0;
      var emitted = 0;
      service.localShowOverrideForTesting = (_) async => shown++;
      final subscription = service.events.listen((_) => emitted++);
      final data = <String, dynamic>{
        'recipient_id': 99,
        'event': 'courier_order_assigned',
        'notification_id': 'push-test-1001',
        'order_id': '7',
        'order_number': '7',
      };

      await service.handleData(data, opened: false);
      await service.handleData(data, opened: false);
      await Future<void>.delayed(Duration.zero);

      expect(shown, 1);
      expect(emitted, 1);
      await subscription.cancel();
      service.localShowOverrideForTesting = null;
    },
  );

  test(
    'different notification ids for the same order remain distinct',
    () async {
      final service = CourierPushService.instance;
      var shown = 0;
      service.localShowOverrideForTesting = (_) async => shown++;

      await service.handleData({
        'recipient_id': 99,
        'event': 'courier_order_assigned',
        'notification_id': 'push-test-2001',
        'order_id': '8',
      }, opened: false);
      await service.handleData({
        'recipient_id': 99,
        'event': 'courier_order_unassigned',
        'notification_id': 'push-test-2002',
        'order_id': '8',
      }, opened: false);

      expect(shown, 2);
      service.localShowOverrideForTesting = null;
    },
  );
}
