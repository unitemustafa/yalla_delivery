import '../domain/app_release.dart';

AppRelease parseAppRelease(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid release.');
  }
  final code = value['version_code'];
  final name = value['version_name'];
  final sha = value['sha256'];
  final size = value['file_size'];
  final rawUrl = value['download_url'];
  final notes = value['release_notes'] ?? '';
  final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
  if (code is! int ||
      code < 1 ||
      code > 2100000000 ||
      name is! String ||
      name.trim().isEmpty ||
      name.length > 40 ||
      sha is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha) ||
      size is! int ||
      size < 1 ||
      size > 100000000 ||
      notes is! String ||
      notes.length > 4000 ||
      url == null ||
      url.scheme != 'https' ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty ||
      url.hasFragment) {
    throw const FormatException('Invalid release metadata.');
  }
  return AppRelease(
    versionCode: code,
    versionName: name,
    downloadUrl: url,
    sha256: sha,
    fileSize: size,
    releaseNotes: notes,
  );
}

UpdateDownload parseUpdateDownload(Map<dynamic, dynamic>? value) {
  if (value == null) throw const FormatException('Missing download state.');
  final phase = switch (value['status']) {
    'idle' => UpdateDownloadPhase.idle,
    'downloading' => UpdateDownloadPhase.downloading,
    'verifying' => UpdateDownloadPhase.verifying,
    'ready' => UpdateDownloadPhase.ready,
    'failed' => UpdateDownloadPhase.failed,
    _ => throw const FormatException('Invalid download state.'),
  };
  return UpdateDownload(
    phase: phase,
    versionCode: (value['version_code'] as num?)?.toInt() ?? 0,
    versionName: value['version_name'] as String? ?? '',
    downloaded: (value['downloaded'] as num?)?.toInt() ?? 0,
    total: (value['total'] as num?)?.toInt() ?? 0,
    message: value['message'] as String? ?? '',
  );
}
