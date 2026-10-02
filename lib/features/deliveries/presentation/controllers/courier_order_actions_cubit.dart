import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/api_result.dart';
import '../../domain/courier_order.dart';
import '../../domain/courier_orders_use_cases.dart';

sealed class CourierOrderActionState {
  const CourierOrderActionState();
}

class CourierOrderActionIdle extends CourierOrderActionState {
  const CourierOrderActionIdle();
}

class CourierOrderActionLoading extends CourierOrderActionState {
  const CourierOrderActionLoading();
}

class CourierOrderActionSuccess extends CourierOrderActionState {
  const CourierOrderActionSuccess(this.order);
  final CourierOrder order;
}

class CourierOrderActionFailure extends CourierOrderActionState {
  const CourierOrderActionFailure(this.message);
  final String message;
}

class CourierOrderActionException implements Exception {
  const CourierOrderActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CourierOrderActionsCubit extends Cubit<CourierOrderActionState> {
  CourierOrderActionsCubit(
    this._load,
    this._pickUp,
    this._pickUpMarket,
    this._deliver,
  ) : super(const CourierOrderActionIdle());
  final LoadCourierOrder _load;
  final PickUpCourierOrder _pickUp;
  final PickUpCourierMarket _pickUpMarket;
  final DeliverCourierOrder _deliver;

  Future<CourierOrder> _run(
    Future<ApiResult<CourierOrder>> Function() operation,
  ) async {
    if (!isClosed) emit(const CourierOrderActionLoading());
    final result = await operation();
    switch (result) {
      case ApiSuccess(:final data):
        if (!isClosed) emit(CourierOrderActionSuccess(data));
        return data;
      case ApiFailure(:final message):
        final text = message ?? 'تعذر تنفيذ العملية. حاول مرة أخرى.';
        if (!isClosed) emit(CourierOrderActionFailure(text));
        throw CourierOrderActionException(text);
    }
  }

  Future<CourierOrder> loadOrder(String id) => _run(() => _load(id));
  Future<CourierOrder> markPickedUp(String id) => _run(() => _pickUp(id));
  Future<CourierOrder> markMarketPickedUp(String id, int sectionId) =>
      _run(() => _pickUpMarket(id, sectionId));
  Future<CourierOrder> markDelivered(
    String id, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) => _run(
    () =>
        _deliver(id, note: note, proofBytes: proofBytes, proofName: proofName),
  );
}
