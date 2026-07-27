import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final environmentPath = arguments
      .where((argument) => !argument.startsWith('--platform='))
      .firstOrNull;
  final platform = arguments
      .where((argument) => argument.startsWith('--platform='))
      .map((argument) => argument.substring('--platform='.length))
      .firstOrNull;
  final errors = <String>[];

  if (environmentPath == null) {
    errors.add('Pass the production JSON file path.');
  } else {
    final file = File(environmentPath);
    if (!file.existsSync()) {
      errors.add('Production environment file is missing.');
    } else {
      try {
        final value = jsonDecode(file.readAsStringSync());
        final environment = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        final apiBaseUrl = environment['API_BASE_URL']?.toString().trim() ?? '';
        final apiUri = Uri.tryParse(apiBaseUrl);
        if (apiUri == null || apiUri.scheme != 'https' || apiUri.host.isEmpty) {
          errors.add('API_BASE_URL must be a valid HTTPS URL.');
        }
      } on FormatException {
        errors.add('Production environment file is not valid JSON.');
      }
    }
  }

  if (platform == null || platform == 'android') {
    if (!File('android/app/google-services.json').existsSync()) {
      errors.add('Android Firebase configuration is missing.');
    }
  }
  if (platform == null || platform == 'ios') {
    if (!File('ios/Runner/GoogleService-Info.plist').existsSync()) {
      errors.add('iOS Firebase configuration is missing.');
    }
    _validateAppleTeam(errors);
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Release preflight failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 2;
    return;
  }
  stdout.writeln('Release preflight passed.');
}

void _validateAppleTeam(List<String> errors) {
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  if (!project.existsSync() ||
      !RegExp(
        r'DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10};',
      ).hasMatch(project.readAsStringSync())) {
    errors.add('Select an Apple Development Team in the iOS Runner target.');
  }
}
