import '../../../core/domain/api_result.dart';
import 'app_release.dart';

abstract interface class AppUpdateRepository {
  Future<ApiResult<AppRelease?>> check();
  Future<ApiResult<UpdateDownload>> download(AppRelease release);
  Future<ApiResult<UpdateDownload>> status();
  Future<ApiResult<void>> install();
}
