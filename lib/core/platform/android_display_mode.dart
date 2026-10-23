import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Requests the portrait presentation used by the Android courier app.
///
/// Android can letterbox a portrait activity when a tablet is held in
/// landscape. Newer large-screen policies may ignore the request, so the app
/// also has a Flutter-side viewport fallback.
Future<void> configureAndroidDisplayMode({TargetPlatform? platform}) async {
  if (kIsWeb || (platform ?? defaultTargetPlatform) != TargetPlatform.android) {
    return;
  }

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
