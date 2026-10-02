import '../../../core/domain/api_result.dart';
import 'login_media.dart';

abstract interface class LoginMediaSource {
  Future<ApiResult<LoginMedia?>> load();
  void dispose();
}
