/// Runs distinct actions in order. Reset detaches a previous session's queue.
class SerialOperation {
  Future<void>? _tail;
  Future<T> run<T>(Future<T> Function() action) {
    final active = _tail;
    final operation = active == null
        ? Future<T>.sync(action)
        : active.then((_) => action());
    late final Future<void> finished;
    finished = operation
        .then<void>((_) {})
        .catchError((Object _) {})
        .whenComplete(() {
          if (identical(_tail, finished)) _tail = null;
        });
    _tail = finished;
    return operation;
  }

  void reset() => _tail = null;
}
