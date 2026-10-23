import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/platform/android_display_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requests portraitUp on Android', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await configureAndroidDisplayMode(platform: TargetPlatform.android);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'SystemChrome.setPreferredOrientations');
    expect(calls.single.arguments, const <String>[
      'DeviceOrientation.portraitUp',
    ]);
  });

  test('does not request an orientation on non-Android platforms', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await configureAndroidDisplayMode(platform: TargetPlatform.iOS);

    expect(calls, isEmpty);
  });
}
