import 'dart:async';

/// Serializes one account's work. A failed task never poisons later retries.
class SyncQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await task());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}
