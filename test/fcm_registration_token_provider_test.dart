import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/notifications/fcm_registration_token_provider.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('waits for APNs registration before requesting an FCM token', () async {
    var apnsCalls = 0;
    final events = <String>[];
    final provider = FcmRegistrationTokenProvider(
      getApnsToken: () async {
        events.add('apns');
        return ++apnsCalls == 3 ? 'apns-token' : null;
      },
      getFcmToken: () async {
        events.add('fcm');
        return 'fcm-token';
      },
      delay: (_) async => events.add('wait'),
    );

    expect(await provider.getToken(), 'fcm-token');
    expect(events, ['apns', 'wait', 'apns', 'wait', 'apns', 'fcm']);
  });

  test(
    'stops after bounded retries without calling FCM when APNs stays unavailable',
    () async {
      var attempts = 0;
      var waits = 0;
      final provider = FcmRegistrationTokenProvider(
        getApnsToken: () async => ++attempts == 1 ? '' : null,
        getFcmToken: () async => fail('FCM requires an APNs token'),
        delay: (_) async => waits++,
      );

      expect(await provider.getToken(), isNull);
      expect(attempts, 10);
      expect(waits, 9);
    },
  );

  test('Android retrieves FCM immediately without touching APNs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final provider = FcmRegistrationTokenProvider(
      getApnsToken: () async => fail('Android must not request APNs'),
      getFcmToken: () async => 'android-token',
      delay: (_) async => fail('Android must not wait'),
    );

    expect(await provider.getToken(), 'android-token');
  });

  test(
    'logout can skip waiting when APNs registration is unavailable',
    () async {
      final provider = FcmRegistrationTokenProvider(
        getApnsToken: () async => null,
        getFcmToken: () async => fail('FCM requires APNs registration'),
        delay: (_) async => fail('Logout must not wait for APNs registration'),
      );

      expect(await provider.getToken(waitForApns: false), isNull);
    },
  );

  test('cancels registration when the session changes while waiting', () async {
    var active = true;
    var attempts = 0;
    final provider = FcmRegistrationTokenProvider(
      getApnsToken: () async {
        attempts++;
        return null;
      },
      getFcmToken: () async => fail('The session ended'),
      delay: (_) async => active = false,
    );

    expect(await provider.getToken(isActive: () => active), isNull);
    expect(attempts, 1);
  });

  test('does not expose a token fetched after the session ends', () async {
    var active = true;
    final provider = FcmRegistrationTokenProvider(
      getApnsToken: () async => 'apns-token',
      getFcmToken: () async {
        active = false;
        return 'old-session-token';
      },
    );

    expect(await provider.getToken(isActive: () => active), isNull);
  });

  test(
    'propagates platform errors to the existing registration failure handler',
    () async {
      final provider = FcmRegistrationTokenProvider(
        getApnsToken: () async => throw StateError('APNs unavailable'),
        getFcmToken: () async => fail('FCM must not run'),
      );

      await expectLater(provider.getToken(), throwsStateError);
    },
  );
}
