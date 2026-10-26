import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/api_result.dart';
import '../../../../core/texts/app_texts.dart';
import '../../../../core/utils/serial_operation.dart';
import '../../domain/courier_notification.dart';
import '../../domain/courier_notifications_use_cases.dart';

class CourierNotificationsState {
  const CourierNotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.totalCount = 0,
    this.hasNext = false,
    this.loading = false,
    this.loadingMore = false,
    this.hasLoaded = false,
    this.markingAll = false,
    this.error,
    this.moreError,
    this.deleting = const {},
    this.reading = const {},
  });
  final List<CourierNotification> items;
  final int unreadCount, totalCount;
  final bool hasNext, loading, loadingMore, hasLoaded, markingAll;
  final String? error, moreError;
  final Set<String> deleting, reading;
  CourierNotificationsState copyWith({
    List<CourierNotification>? items,
    int? unreadCount,
    int? totalCount,
    bool? hasNext,
    bool? loading,
    bool? loadingMore,
    bool? hasLoaded,
    bool? markingAll,
    String? error,
    String? moreError,
    bool clearError = false,
    bool clearMoreError = false,
    Set<String>? deleting,
    Set<String>? reading,
  }) => CourierNotificationsState(
    items: items ?? this.items,
    unreadCount: unreadCount ?? this.unreadCount,
    totalCount: totalCount ?? this.totalCount,
    hasNext: hasNext ?? this.hasNext,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    markingAll: markingAll ?? this.markingAll,
    error: clearError ? null : error ?? this.error,
    moreError: clearMoreError ? null : moreError ?? this.moreError,
    deleting: deleting ?? this.deleting,
    reading: reading ?? this.reading,
  );
}

class CourierNotificationActionException implements Exception {
  const CourierNotificationActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cubit state with a Listenable adapter for the existing screen contract.
class CourierNotificationsController extends Cubit<CourierNotificationsState>
    implements Listenable {
  CourierNotificationsController({
    required CourierNotificationsUseCases useCases,
  }) : _useCases = useCases,
       super(const CourierNotificationsState());
  final CourierNotificationsUseCases _useCases;
  final _listeners = _NotificationListeners();
  final _queue = SerialOperation();
  int _generation = 0, _page = 0;
  bool _disposed = false, _dirtyPages = false;
  Future<void>? _loadInFlight, _moreInFlight;
  List<CourierNotification> get notifications => state.items;
  int get unreadCount => state.unreadCount;
  int get totalCount => state.totalCount;
  bool get hasNext => state.hasNext;
  bool get isLoading => state.loading;
  bool get isLoadingMore => state.loadingMore;
  bool get hasLoaded => state.hasLoaded;
  bool get isMarkingAllRead => state.markingAll;
  String? get errorMessage => state.error;
  String? get moreError => state.moreError;
  bool isDeleting(CourierNotification item) => state.deleting.contains(item.id);
  bool isReading(CourierNotification item) => state.reading.contains(item.id);
  @override
  void addListener(VoidCallback listener) => _listeners.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _listeners.removeListener(listener);
  bool _current(int generation) =>
      !_disposed && !isClosed && generation == _generation;
  void _publish(CourierNotificationsState next) {
    if (_disposed || isClosed) return;
    emit(next);
    _listeners.changed();
  }

  T _value<T>(ApiResult<T> result) => switch (result) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw CourierNotificationActionException(
      message ?? NotificationTexts.loadFailedRetry,
    ),
  };
  Future<void> loadNotifications() {
    if (_disposed) return Future.value();
    final pending = _loadInFlight;
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<void> operation;
    operation = _queue.run(() => _load(generation)).whenComplete(() {
      if (identical(_loadInFlight, operation)) _loadInFlight = null;
    });
    _loadInFlight = operation;
    return operation;
  }

  Future<void> loadNotificationsIfNeeded() =>
      hasLoaded ? Future.value() : loadNotifications();
  Future<void> refreshNotifications() => loadNotifications();
  Future<void> _load(int generation) async {
    if (!_current(generation)) return;
    final previous = state;
    final pages = _page < 1 ? 1 : _page;
    _publish(
      previous.copyWith(
        loading: true,
        loadingMore: false,
        clearError: true,
        clearMoreError: true,
      ),
    );
    final items = <String, CourierNotification>{};
    var loaded = 0;
    try {
      for (var page = 1; page <= pages; page++) {
        final response = await _useCases.load(page: page);
        if (!_current(generation)) return;
        final data = _value(response);
        for (final item in data.items) {
          items[item.id] = item;
        }
        loaded = page;
        if (!data.hasNext || page == pages) {
          _page = loaded;
          _dirtyPages = false;
          _publish(
            CourierNotificationsState(
              items: List.unmodifiable(items.values),
              unreadCount: data.unreadCount,
              totalCount: data.count,
              hasNext: data.hasNext,
              hasLoaded: true,
            ),
          );
          return;
        }
      }
    } catch (error) {
      if (_current(generation)) {
        _publish(
          previous.copyWith(
            loading: false,
            loadingMore: false,
            error: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> loadMore() {
    if (_disposed) return Future.value();
    final pending = _moreInFlight;
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<void> operation;
    operation = _queue
        .run(() async {
          if (!_current(generation)) return;
          if (_dirtyPages) {
            await _load(generation);
            if (_dirtyPages || !_current(generation)) return;
          }
          if (!state.hasNext) return;
          _publish(state.copyWith(loadingMore: true, clearMoreError: true));
          try {
            final response = await _useCases.load(page: _page + 1);
            if (!_current(generation)) return;
            final data = _value(response);
            _page++;
            final items = {
              for (final item in state.items) item.id: item,
              for (final item in data.items) item.id: item,
            };
            _publish(
              state.copyWith(
                items: List.unmodifiable(items.values),
                totalCount: data.count,
                unreadCount: data.unreadCount,
                hasNext: data.hasNext,
                loadingMore: false,
                clearMoreError: true,
              ),
            );
          } catch (error) {
            if (_current(generation)) {
              _publish(
                state.copyWith(loadingMore: false, moreError: error.toString()),
              );
            }
          }
        })
        .whenComplete(() {
          if (identical(_moreInFlight, operation)) _moreInFlight = null;
        });
    _moreInFlight = operation;
    return operation;
  }

  Future<void> refreshUnreadCount() {
    final generation = _generation;
    return _queue.run(() async {
      if (!_current(generation)) return;
      final response = await _useCases.unread();
      if (_current(generation)) {
        _publish(state.copyWith(unreadCount: _value(response)));
      }
    });
  }

  Future<CourierNotification> markRead(CourierNotification notification) {
    final generation = _generation;
    return _queue.run(() async {
      if (!_current(generation)) {
        throw const CourierNotificationActionException(
          NotificationTexts.loadFailedRetry,
        );
      }
      final current =
          state.items.where((i) => i.id == notification.id).firstOrNull ??
          notification;
      if (current.isRead) return current;
      _publish(state.copyWith(reading: {...state.reading, current.id}));
      try {
        final response = await _useCases.read(current);
        if (!_current(generation)) {
          throw const CourierNotificationActionException(
            NotificationTexts.loadFailedRetry,
          );
        }
        final updated = _value(response);
        _publish(
          state.copyWith(
            items: List.unmodifiable([
              for (final item in state.items)
                if (item.id == updated.id) updated else item,
            ]),
            unreadCount: updated.isRead
                ? (state.unreadCount - 1).clamp(0, state.unreadCount)
                : state.unreadCount,
          ),
        );
        return updated;
      } finally {
        if (_current(generation)) {
          _publish(
            state.copyWith(reading: {...state.reading}..remove(current.id)),
          );
        }
      }
    });
  }

  Future<int> markAllRead() {
    final generation = _generation;
    return _queue.run(() async {
      if (!_current(generation)) return 0;
      _publish(state.copyWith(markingAll: true));
      try {
        final response = await _useCases.readAll();
        if (!_current(generation)) return 0;
        final count = _value(response);
        _publish(
          state.copyWith(
            items: List.unmodifiable([
              for (final item in state.items)
                item.copyWith(isRead: true, readAt: DateTime.now()),
            ]),
            unreadCount: 0,
          ),
        );
        return count;
      } finally {
        if (_current(generation)) _publish(state.copyWith(markingAll: false));
      }
    });
  }

  Future<void> deleteNotification(CourierNotification notification) {
    final generation = _generation;
    return _queue.run(() async {
      if (!_current(generation)) return;
      final current = state.items
          .where((i) => i.id == notification.id)
          .firstOrNull;
      if (current == null) return;
      _publish(state.copyWith(deleting: {...state.deleting, current.id}));
      try {
        final response = await _useCases.delete(current.id);
        if (!_current(generation)) return;
        _value(response);
        _dirtyPages = true;
        _publish(
          state.copyWith(
            items: List.unmodifiable(
              state.items.where((i) => i.id != current.id),
            ),
            totalCount: (state.totalCount - 1).clamp(0, state.totalCount),
            unreadCount: current.isRead
                ? state.unreadCount
                : (state.unreadCount - 1).clamp(0, state.unreadCount),
          ),
        );
      } finally {
        if (_current(generation)) {
          _publish(
            state.copyWith(deleting: {...state.deleting}..remove(current.id)),
          );
        }
      }
    });
  }

  void clear() {
    if (_disposed) return;
    _generation++;
    _queue.reset();
    _page = 0;
    _dirtyPages = false;
    _loadInFlight = null;
    _moreInFlight = null;
    _publish(const CourierNotificationsState());
  }

  void dispose() => unawaited(close());
  @override
  Future<void> close() {
    if (_disposed) return Future.value();
    _generation++;
    _disposed = true;
    _queue.reset();
    _listeners.dispose();
    return super.close();
  }
}

class _NotificationListeners extends ChangeNotifier {
  void changed() => notifyListeners();
}
