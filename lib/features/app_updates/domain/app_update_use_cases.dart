import '../../../core/domain/api_result.dart';
import 'app_release.dart';
import 'app_update_repository.dart';

class CheckForAppUpdate {
  const CheckForAppUpdate(this._repository);
  final AppUpdateRepository _repository;
  Future<ApiResult<AppRelease?>> call() => _repository.check();
}

class DownloadAppUpdate {
  const DownloadAppUpdate(this._repository);
  final AppUpdateRepository _repository;
  Future<ApiResult<UpdateDownload>> call(AppRelease release) =>
      _repository.download(release);
}

class ReadAppUpdateDownload {
  const ReadAppUpdateDownload(this._repository);
  final AppUpdateRepository _repository;
  Future<ApiResult<UpdateDownload>> call() => _repository.status();
}

class InstallAppUpdate {
  const InstallAppUpdate(this._repository);
  final AppUpdateRepository _repository;
  Future<ApiResult<void>> call() => _repository.install();
}
