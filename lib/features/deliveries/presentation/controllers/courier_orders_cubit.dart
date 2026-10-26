import 'dart:async';
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
    this.activeTotals,
    this.hasNextActive = false,
    this.loadingMoreActive = false,
    this.activeMoreError,
    this.loading = false,
    this.loadingHistory = false,
    this.hasNext = false,
    this.error,
    this.historyError,
  });
  final List<CourierOrder> active;
  final List<CourierOrder> history;
  final CourierOrderTotals? totals;
  final CourierOrderTotals? activeTotals;
  final bool hasNextActive;
  final bool loadingMoreActive;
  final String? activeMoreError;
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
  int _activePage = 0;
  int _activeRevision = 0;
  Future<void>? _activeFlight;
  Future<void>? _historyFlight;
  ({DateTime? from, DateTime? before})? _pendingHistoryRange;
  bool _pendingActiveRefresh = false;
  bool _dirtyActivePages = false;
  DateTime? _from;
  DateTime? _before;

  void _update({
    List<CourierOrder>? active,
    List<CourierOrder>? history,
    CourierOrderTotals? totals,
    CourierOrderTotals? activeTotals,
    bool? hasNextActive,
    bool? loadingMoreActive,
    String? activeMoreError,
    bool? loading,
    bool? loadingHistory,
    bool? hasNext,
    String? error,
    String? historyError,
    bool clearError = false,
    bool clearHistoryError = false,
    bool clearActiveMoreError = false,
  }) {
    if (isClosed) return;
    emit(
      CourierOrdersState(
        active: active ?? state.active,
        history: history ?? state.history,
        totals: totals ?? state.totals,
        activeTotals: activeTotals ?? state.activeTotals,
        hasNextActive: hasNextActive ?? state.hasNextActive,
        loadingMoreActive: loadingMoreActive ?? state.loadingMoreActive,
        activeMoreError: clearActiveMoreError
            ? null
            : activeMoreError ?? state.activeMoreError,
        loading: loading ?? state.loading,
        loadingHistory: loadingHistory ?? state.loadingHistory,
        hasNext: hasNext ?? state.hasNext,
        error: clearError ? null : error ?? state.error,
        historyError: clearHistoryError
            ? null
            : historyError ?? state.historyError,
      ),
    );
  }

  Future<void> refreshActive({bool invalidated = false}) {
    if (isClosed) return Future.value();
    final pending = _activeFlight;
    if (pending != null) {
      _pendingActiveRefresh = _pendingActiveRefresh || invalidated;
      return pending;
    }
    return _runActive(_refreshActiveSnapshot);
  }

  Future<void> _runActive(Future<void> Function() action) {
    late final Future<void> pending;
    pending =
        (() async {
          await action();
          while (_pendingActiveRefresh && !isClosed) {
            _pendingActiveRefresh = false;
            await _refreshActiveSnapshot();
          }
        })().whenComplete(() {
          if (identical(_activeFlight, pending)) _activeFlight = null;
        });
    _activeFlight = pending;
    return pending;
  }

  Future<void> _refreshActiveSnapshot() async {
    final revision = _activeRevision;
    final pages = _activePage < 1 ? 1 : _activePage;
    _update(
      loading: true,
      loadingMoreActive: false,
      clearError: true,
      clearActiveMoreError: true,
    );
    final merged = <String, CourierOrder>{};
    CourierOrderPage? last;
    var loaded = 0;
    for (var page = 1; page <= pages; page++) {
      final result = await _active.page(page: page);
      if (isClosed || revision != _activeRevision) return;
      switch (result) {
        case ApiSuccess(:final data):
          last = data;
          loaded = page;
          for (final order in data.orders) {
            merged[order.id] = order;
          }
        case ApiFailure(:final message):
          _update(loading: false, error: message);
          return;
      }
      if (!last.hasNext) break;
    }
    _activePage = loaded;
    _dirtyActivePages = false;
    _update(
      active: List.unmodifiable(merged.values),
      activeTotals: last!.totals,
      hasNextActive: last.hasNext,
      loading: false,
    );
  }

  Future<void> loadMoreActive() {
    if (isClosed) return Future.value();
    final pending = _activeFlight;
    if (pending != null) return pending;
    if (!state.hasNextActive) return Future.value();
    return _runActive(() async {
      if (_dirtyActivePages) {
        await _refreshActiveSnapshot();
        if (_dirtyActivePages || isClosed) return;
      }
      if (!state.hasNextActive) return;
      final revision = _activeRevision;
      _update(loadingMoreActive: true, clearActiveMoreError: true);
      final result = await _active.page(page: _activePage + 1);
      if (isClosed || revision != _activeRevision) return;
      switch (result) {
        case ApiSuccess(:final data):
          _activePage++;
          final merged = {
            for (final order in state.active) order.id: order,
            for (final order in data.orders) order.id: order,
          };
          _update(
            active: List.unmodifiable(merged.values),
            activeTotals: data.totals,
            hasNextActive: data.hasNext,
            loadingMoreActive: false,
          );
        case ApiFailure(:final message):
          _update(loadingMoreActive: false, activeMoreError: message);
      }
    });
  }

  Future<void> refreshHistory({DateTime? from, DateTime? before}) {
    if (isClosed) return Future.value();
    final pending = _historyFlight;
    if (pending != null) {
      _pendingHistoryRange = (from: from, before: before);
      return pending;
    }
    return _runHistory(
      () => _refreshHistorySnapshot(from: from, before: before),
    );
  }

  Future<void> _runHistory(Future<void> Function() action) {
    late final Future<void> operation;
    operation =
        (() async {
          await action();
          while (_pendingHistoryRange != null && !isClosed) {
            final range = _pendingHistoryRange!;
            _pendingHistoryRange = null;
            await _refreshHistorySnapshot(
              from: range.from,
              before: range.before,
            );
          }
        })().whenComplete(() {
          if (identical(_historyFlight, operation)) _historyFlight = null;
        });
    _historyFlight = operation;
    return operation;
  }

  Future<void> _refreshHistorySnapshot({
    DateTime? from,
    DateTime? before,
  }) async {
    final changedRange = from != _from || before != _before;
    final pages = changedRange || _page < 1 ? 1 : _page;
    _from = from;
    _before = before;
    _update(
      loadingHistory: true,
      clearHistoryError: true,
      history: changedRange ? const [] : null,
      totals: changedRange
          ? const CourierOrderTotals(count: 0, value: 0, deliveryFees: 0)
          : null,
      hasNext: changedRange ? false : null,
    );
    if (changedRange) _page = 0;
    final merged = <String, CourierOrder>{};
    CourierOrderPage? last;
    var loaded = 0;
    for (var page = 1; page <= pages; page++) {
      final result = await _history(page: page, from: from, before: before);
      if (isClosed) return;
      switch (result) {
        case ApiSuccess(:final data):
          loaded = page;
          last = data;
          for (final order in data.orders) {
            merged[order.id] = order;
          }
        case ApiFailure(:final message):
          _update(loadingHistory: false, historyError: message);
          return;
      }
      if (!last.hasNext) break;
    }
    _page = loaded;
    _update(
      history: List.unmodifiable(merged.values),
      totals: last!.totals,
      hasNext: last.hasNext,
      loadingHistory: false,
    );
  }

  Future<void> loadMoreHistory() {
    if (isClosed) return Future.value();
    final pending = _historyFlight;
    if (pending != null) return pending;
    if (!state.hasNext) return Future.value();
    return _runHistory(() async {
      _update(loadingHistory: true, clearHistoryError: true);
      final result = await _history(
        page: _page + 1,
        from: _from,
        before: _before,
      );
      if (isClosed) return;
      switch (result) {
        case ApiSuccess(:final data):
          _page++;
          final byId = {
            for (final order in state.history) order.id: order,
            for (final order in data.orders) order.id: order,
          };
          _update(
            history: List.unmodifiable(byId.values),
            totals: data.totals,
            hasNext: data.hasNext,
            loadingHistory: false,
          );
        case ApiFailure(:final message):
          _update(loadingHistory: false, historyError: message);
      }
    });
  }

  void replaceOrder(CourierOrder updated) {
    _activeRevision++;
    _dirtyActivePages = true;
    if (_activeFlight != null) _pendingActiveRefresh = true;
    final previous = state.active
        .where((order) => order.id == updated.id)
        .firstOrNull;
    final totals = state.activeTotals;
    CourierOrderTotals? nextTotals;
    if (previous != null && totals != null) {
      final oldActive = previous.isActiveCourierOrder;
      final newActive = updated.isActiveCourierOrder;
      nextTotals = CourierOrderTotals(
        count: totals.count + (newActive ? 1 : 0) - (oldActive ? 1 : 0),
        value:
            totals.value +
            (newActive ? updated.total : 0) -
            (oldActive ? previous.total : 0),
        deliveryFees:
            totals.deliveryFees +
            (newActive ? updated.deliveryPrice ?? 0 : 0) -
            (oldActive ? previous.deliveryPrice ?? 0 : 0),
        pickupRequiredCount: totals.pickupRequiredCount == null
            ? null
            : totals.pickupRequiredCount! +
                  (updated.requiresPickup ? 1 : 0) -
                  (previous.requiresPickup ? 1 : 0),
      );
    }
    if (previous == null && _activeFlight == null) {
      unawaited(refreshActive(invalidated: true));
    }
    _update(
      activeTotals: nextTotals,
      active: [
        for (final order in state.active)
          if (order.id == updated.id) updated else order,
      ],
    );
  }
}
