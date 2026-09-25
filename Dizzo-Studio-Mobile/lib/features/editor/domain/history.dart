/// Undo/redo over immutable snapshots (the web keeps 60 steps).
class History<T> {
  History({this.limit = 60});

  final int limit;
  final List<T> _past = [];
  final List<T> _future = [];

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  /// Records [current] before a change.
  void checkpoint(T current) {
    _past.add(current);
    if (_past.length > limit) _past.removeAt(0);
    _future.clear();
  }

  /// The state to go back to, given the [current] one.
  T? undo(T current) {
    if (_past.isEmpty) return null;
    _future.add(current);
    return _past.removeLast();
  }

  T? redo(T current) {
    if (_future.isEmpty) return null;
    _past.add(current);
    return _future.removeLast();
  }

  void clear() {
    _past.clear();
    _future.clear();
  }
}
