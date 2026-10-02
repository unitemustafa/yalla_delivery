import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/api_result.dart';
import '../../domain/courier_order.dart';
import '../../domain/courier_order_page.dart';
import '../../domain/courier_orders_use_cases.dart';

class CourierOrdersState {
  const CourierOrdersState({
    this.active = const [],
    this.history = const [],
    this.totals,
    this.loading = false,
    this.loadingHistory = false,
    this.hasNext = false,
    this.error,
    this.historyError,
  });
  final List<CourierOrder> active;
  final List<CourierOrder> history;
  final CourierOrderTotals? totals;
  final bool loading;
  final bool loadingHistory;
  final bool hasNext;
  final String? error;
  final String? historyError;
}

class CourierOrdersCubit extends Cubit<CourierOrdersState> {
  CourierOrdersCubit(this._active, this._history)
    : super(const CourierOrdersState());
  final LoadActiveCourierOrders _active;
  final LoadCourierHistory _history;
  int _page = 0;
  DateTime? _from;
  DateTime? _before;

  void _update({
    List<CourierOrder>? active,
    List<CourierOrder>? history,
    CourierOrderTotals? totals,
    bool? loading,
    bool? loadingHistory,
    bool? hasNext,
    String? error,
    String? historyError,
  }) {
    if (isClosed) return;
    emit(
      CourierOrdersState(
        active: active ?? state.active,
        history: history ?? state.history,
        totals: totals ?? state.totals,
        loading: loading ?? state.loading,
        loadingHistory: loadingHistory ?? state.loadingHistory,
        hasNext: hasNext ?? state.hasNext,
        error: error,
        historyError: historyError,
      ),
    );
  }

  Future<void> refreshActive() async {
    if (state.loading || isClosed) return;
    _update(loading: true);
    switch (await _active()) {
      case ApiSuccess(:final data):
        _update(active: data, loading: false);
      case ApiFailure(:final message):
        _update(loading: false, error: message);
    }
  }

  Future<void> refreshHistory({DateTime? from, DateTime? before}) async {
    if (state.loadingHistory || isClosed) return;
    final changedRange = from != _from || before != _before;
    _from = from;
    _before = before;
    _update(
      loadingHistory: true,
      history: changedRange ? const [] : null,
      totals: changedRange
          ? const CourierOrderTotals(count: 0, value: 0, deliveryFees: 0)
          : null,
      hasNext: changedRange ? false : null,
    );
    switch (await _history(from: from, before: before)) {
      case ApiSuccess(:final data):
        _page = 1;
        _update(
          history: data.orders,
          totals: data.totals,
          hasNext: data.hasNext,
          loadingHistory: false,
        );
      case ApiFailure(:final message):
        _update(loadingHistory: false, historyError: message);
    }
  }

  Future<void> loadMoreHistory() async {
    if (state.loadingHistory || !state.hasNext || isClosed) return;
    _update(loadingHistory: true);
    switch (await _history(page: _page + 1, from: _from, before: _before)) {
      case ApiSuccess(:final data):
        _page++;
        final byId = {
          for (final order in [...state.history, ...data.orders])
            order.id: order,
        };
        _update(
          history: byId.values.toList(),
          totals: data.totals,
          hasNext: data.hasNext,
          loadingHistory: false,
        );
      case ApiFailure(:final message):
        _update(loadingHistory: false, historyError: message);
    }
  }

  void replaceOrder(CourierOrder updated) {
    _update(
      active: [
        for (final order in state.active)
          if (order.id == updated.id) updated else order,
      ],
    );
  }
}
