import '../../../core/domain/api_result.dart';
import 'courier_order.dart';
import 'courier_order_page.dart';
import 'courier_orders_repository.dart';

class LoadActiveCourierOrders {
  const LoadActiveCourierOrders(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<List<CourierOrder>>> call() => _repository.loadActive();
}

class LoadCourierHistory {
  const LoadCourierHistory(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<CourierOrderPage>> call({
    int page = 1,
    DateTime? from,
    DateTime? before,
  }) => _repository.loadHistory(page: page, from: from, before: before);
}

class LoadCourierOrder {
  const LoadCourierOrder(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<CourierOrder>> call(String id) => _repository.loadOrder(id);
}

class PickUpCourierOrder {
  const PickUpCourierOrder(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<CourierOrder>> call(String id) => _repository.pickUp(id);
}

class PickUpCourierMarket {
  const PickUpCourierMarket(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<CourierOrder>> call(String id, int sectionId) =>
      _repository.pickUpMarket(id, sectionId);
}

class DeliverCourierOrder {
  const DeliverCourierOrder(this._repository);
  final CourierOrdersRepository _repository;
  Future<ApiResult<CourierOrder>> call(
    String id, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) => _repository.deliver(
    id,
    note: note,
    proofBytes: proofBytes,
    proofName: proofName,
  );
}
