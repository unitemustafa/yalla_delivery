import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/constants/app_constants.dart';

void main() {
  test('visible branding uses Yalla Delivery', () {
    expect(AppConstants.appName, 'Yalla Delivery');

    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidStrings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(androidManifest, contains('android:label="@string/app_name"'));
    expect(
      androidStrings,
      anyOf(contains('Yalla Delivery'), contains('يلا دليفيري')),
    );

    const brandedFiles = [
      'ios/Runner/Info.plist',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'web/manifest.json',
      'web/index.html',
      'linux/runner/my_application.cc',
      'windows/runner/Runner.rc',
      'windows/runner/main.cpp',
      'README.md',
      'docs/RELEASE_CHECKLIST.md',
    ];

    for (final path in brandedFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        anyOf(contains('Yalla Delivery'), contains('يلا دليفيري')),
        reason: path,
      );
      expect(source, isNot(contains('Yalla Home')), reason: path);
      expect(source, isNot(contains('يلا هوم')), reason: path);
    }
  });

  test('feature domain code stays independent of Flutter presentation', () {
    final domainFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final path = file.path.replaceAll('\\', '/');
          return path.contains('/domain/') && path.endsWith('.dart');
        });

    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains("package:flutter/")), reason: file.path);
      expect(
        source,
        isNot(contains('core/constants/app_colors.dart')),
        reason: file.path,
      );
    }
  });
}
