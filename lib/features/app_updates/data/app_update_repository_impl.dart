import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/domain/api_result.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_release.dart';
import '../domain/app_update_repository.dart';
import 'android_update_platform.dart';
import 'app_update_api.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  const AppUpdateRepositoryImpl(this._api, this._platform);
  final AppUpdateApi _api;
  final AndroidUpdatePlatform _platform;

  Future<ApiResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return ApiSuccess(await action());
    } on PlatformException catch (error) {
      return ApiFailure(ApiFailureReason.server, message: error.message);
    } on ApiException catch (error) {
      return ApiFailure(ApiFailureReason.server, message: error.message);
    } on FormatException {
      return const ApiFailure(
        ApiFailureReason.invalidResponse,
        message: 'بيانات التحديث غير صالحة. حاول لاحقًا.',
      );
    } on TimeoutException {
      return const ApiFailure(
        ApiFailureReason.network,
        message: 'انتهت مهلة الاتصال. تأكد من الإنترنت وحاول مرة أخرى.',
      );
    } on http.ClientException {
      return const ApiFailure(
        ApiFailureReason.network,
        message: 'تعذّر الاتصال بالسيرفر. تأكد من الإنترنت.',
      );
    } catch (_) {
      return const ApiFailure(
        ApiFailureReason.server,
        message: 'تعذّر تنفيذ التحديث. حاول مرة أخرى.',
      );
    }
  }

  @override
  Future<ApiResult<AppRelease?>> check() => _guard(() async {
    final version = await _platform.installedVersion();
    return version == null ? null : _api.latest(version);
  });

  @override
  Future<ApiResult<UpdateDownload>> status() => _guard(_platform.status);
  @override
  Future<ApiResult<UpdateDownload>> download(AppRelease release) =>
      _guard(() => _platform.download(release));
  @override
  Future<ApiResult<void>> install() => _guard(_platform.install);
}
