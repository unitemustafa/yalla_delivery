import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/app_release.dart';
import 'app_update_models.dart';

class AndroidUpdatePlatform {
  const AndroidUpdatePlatform();
  static const _channel = MethodChannel('yalla_delivery/app_updates');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<int?> installedVersion() async {
    if (!supported) return null;
    return await _channel.invokeMethod<int>('installedVersion');
  }

  Future<UpdateDownload> status() async {
    if (!supported) {
      return const UpdateDownload(phase: UpdateDownloadPhase.idle);
    }
    return parseUpdateDownload(await _channel.invokeMapMethod('status'));
  }

  Future<UpdateDownload> download(AppRelease release) async {
    if (!supported) throw const FormatException('Android only.');
    return parseUpdateDownload(
      await _channel.invokeMapMethod('download', {
        'version_code': release.versionCode,
        'version_name': release.versionName,
        'download_url': release.downloadUrl.toString(),
        'sha256': release.sha256,
        'file_size': release.fileSize,
      }),
    );
  }

  Future<void> install() async => _channel.invokeMethod<void>('install');
}
