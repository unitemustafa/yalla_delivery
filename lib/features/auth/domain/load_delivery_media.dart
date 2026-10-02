import '../../../core/domain/api_result.dart';
import 'login_media.dart';
import 'login_media_repository.dart';

class LoadDeliveryMedia {
  const LoadDeliveryMedia(this._source);
  final LoginMediaSource _source;
  Future<ApiResult<LoginMedia?>> call() => _source.load();
  void dispose() => _source.dispose();
}
