import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// APNs registration is asynchronous, even after permission has been granted.
class FcmRegistrationTokenProvider {
  FcmRegistrationTokenProvider({
    Future<String?> Function()? getApnsToken,
    Future<String?> Function()? getFcmToken,
    Future<void> Function(Duration)? delay,
  }) : _getApnsToken =
           getApnsToken ?? (() => FirebaseMessaging.instance.getAPNSToken()),
       _getFcmToken =
           getFcmToken ?? (() => FirebaseMessaging.instance.getToken()),
       _delay = delay ?? Future<void>.delayed;

  final Future<String?> Function() _getApnsToken;
  final Future<String?> Function() _getFcmToken;
  final Future<void> Function(Duration) _delay;

  Future<String?> getToken({
    bool Function()? isActive,
    bool waitForApns = true,
  }) async {
    bool active() => isActive?.call() ?? true;
    if (!active()) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final maxAttempts = waitForApns ? 10 : 1;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!active()) return null;
        final apnsToken = await _getApnsToken();
        if (!active()) return null;
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        if (attempt == maxAttempts - 1) return null;
        await _delay(const Duration(seconds: 1));
      }
    }
    if (!active()) return null;
    final token = await _getFcmToken();
    return active() ? token : null;
  }
}
