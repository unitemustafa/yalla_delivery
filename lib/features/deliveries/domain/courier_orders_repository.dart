import '../../../core/domain/api_result.dart';
import 'courier_order.dart';
import 'courier_order_page.dart';

abstract interface class CourierOrdersRepository {
  Future<ApiResult<List<CourierOrder>>> loadActive();
  Future<ApiResult<CourierOrderPage>> loadHistory({
    int page = 1,
    DateTime? from,
    DateTime? before,
  });
  Future<ApiResult<CourierOrder>> loadOrder(String id);
  Future<ApiResult<CourierOrder>> pickUp(String id);
  Future<ApiResult<CourierOrder>> pickUpMarket(String id, int sectionId);
  Future<ApiResult<CourierOrder>> deliver(
    String id, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  });
}
