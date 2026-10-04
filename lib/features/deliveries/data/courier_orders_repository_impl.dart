import '../../../core/domain/api_result.dart';
import '../../../core/texts/app_texts.dart';
import '../../../core/network/api_exception.dart';
import '../domain/courier_order.dart';
import '../domain/courier_order_page.dart';
import '../domain/courier_orders_repository.dart';
import 'courier_orders_api.dart';

class CourierOrdersRepositoryImpl implements CourierOrdersRepository {
  const CourierOrdersRepositoryImpl(this._api);
  final CourierOrdersApi _api;

  Future<ApiResult<T>> _result<T>(Future<T> Function() operation) async {
    try {
      return ApiSuccess(await operation());
    } on ApiException catch (error) {
      return ApiFailure(
        error.statusCode == null
            ? ApiFailureReason.network
            : ApiFailureReason.server,
        message: error.message,
      );
    } on FormatException {
      return const ApiFailure(
        ApiFailureReason.invalidResponse,
        message: AuthTexts.incompleteOrderResponse,
      );
    } catch (_) {
      return const ApiFailure(
        ApiFailureReason.network,
        message: CommonTexts.connectionFailed,
      );
    }
  }

  @override
  Future<ApiResult<List<CourierOrder>>> loadActive() =>
      _result(_api.loadOrders);
  @override
  Future<ApiResult<CourierOrderPage>> loadHistory({
    int page = 1,
    DateTime? from,
    DateTime? before,
  }) => _result(
    () => _api.loadHistoryPage(page: page, from: from, before: before),
  );
  @override
  Future<ApiResult<CourierOrder>> loadOrder(String id) =>
      _result(() => _api.loadOrder(id));
  @override
  Future<ApiResult<CourierOrder>> pickUp(String id) =>
      _result(() => _api.markPickedUp(id));
  @override
  Future<ApiResult<CourierOrder>> pickUpMarket(String id, int sectionId) =>
      _result(() => _api.markMarketPickedUp(id, sectionId));
  @override
  Future<ApiResult<CourierOrder>> deliver(
    String id, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) => _result(
    () => _api.markDelivered(
      id,
      note: note,
      proofBytes: proofBytes,
      proofName: proofName,
    ),
  );
}
