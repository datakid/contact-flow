class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'CancelledException';
}

class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final all = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final f in all) {
      f();
    }
  }

  void onCancel(void Function() f) {
    if (_cancelled) {
      f();
    } else {
      _listeners.add(f);
    }
  }
}
