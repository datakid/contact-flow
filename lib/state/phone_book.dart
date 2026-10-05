import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/contact_source.dart';
import '../data/executor.dart';
import '../data/journal.dart';
import '../domain/change_set.dart';
import '../models/person.dart';
import 'contact_list.dart';

enum LoadState { idle, loading, ready, failed }

class RunState {
  final ChangeSet set;
  final ExecutionProgress progress;
  final CancelToken token;
  const RunState(this.set, this.progress, this.token);
}

class PhoneBook extends ContactList {
  final ContactSource source;
  final Journal journal;
  late final Executor _executor = Executor(source, journal);

  Access access = Access.notAsked;
  LoadState load = LoadState.idle;
  String error = '';
  List<AccountRef> accounts = const [];
  List<String> groupNames = const [];
  RunState? running;
  StreamSubscription<void>? _changes;
  Timer? _changeDebounce;
  bool _journalLoaded = false;
  bool _suppressChanges = false;

  PhoneBook(this.source, this.journal);

  bool get isDevice => source.isDevice;
  bool get isDemo => !source.isDevice;
  bool get granted => access == Access.granted;
  bool get busy => running != null;

  Future<void> ensureJournal() async {
    if (_journalLoaded) return;
    _journalLoaded = true;
    try {
      await journal.load();
    } catch (_) {}
  }

  Future<void> checkAccess() async {
    access = await source.status();
    notifyListeners();
    if (granted && load == LoadState.idle) await refresh();
  }

  Future<Access> requestAccess() async {
    access = await source.request();
    notifyListeners();
    if (granted) await refresh();
    return access;
  }

  Future<void> openSettings() => source.openSettings();

  Future<void> startDemo() async {
    final s = source;
    if (s is FakeSource && s.access != Access.granted) {
      s.access = Access.granted;
    }
    await checkAccess();
  }

  Future<void> refresh({bool quiet = false}) async {
    if (!granted || load == LoadState.loading) return;
    if (!quiet || people.isEmpty) {
      load = LoadState.loading;
      notifyListeners();
    }
    try {
      await ensureJournal();
      final list = await source.readAll();
      accounts = await _safe(source.accounts(), const <AccountRef>[]);
      groupNames = await _safe(source.groups(), const <String>[]);
      replacePeople(list);
      load = LoadState.ready;
      error = '';
      _listen();
      notifyListeners();
    } catch (e) {
      load = LoadState.failed;
      error = Executor.describe(e);
      notifyListeners();
    }
  }

  static Future<T> _safe<T>(Future<T> f, T fallback) async {
    try {
      return await f;
    } catch (_) {
      return fallback;
    }
  }

  void _listen() {
    _changes ??= source.changes.listen((_) {
      if (_suppressChanges || busy) return;
      _changeDebounce?.cancel();
      _changeDebounce = Timer(
        const Duration(milliseconds: 600),
        () => refresh(quiet: true),
      );
    });
  }

  Future<void> onResume() async {
    final before = access;
    access = await source.status();
    if (access != before) notifyListeners();
    if (granted) await refresh(quiet: true);
  }

  Set<String> get allGroups => {
    ...groupNames,
    for (final p in people) ...p.groups,
  };

  Map<String, int> get accountCounts {
    final out = <String, int>{};
    for (final p in people) {
      final k = (p.account ?? AccountRef.device).key;
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  AccountRef accountFor(String key) {
    for (final a in accounts) {
      if (a.key == key) return a;
    }
    for (final p in people) {
      if ((p.account ?? AccountRef.device).key == key) {
        return p.account ?? AccountRef.device;
      }
    }
    return AccountRef.device;
  }

  Future<ExecutionResult?> apply(
    ChangeSet set, {
    String? undoOf,
    void Function(ExecutionProgress)? onProgress,
  }) async {
    if (set.isEmpty || busy) return null;
    await ensureJournal();
    final token = CancelToken();
    running = RunState(set, ExecutionProgress(0, set.length), token);
    _suppressChanges = true;
    notifyListeners();
    try {
      final r = await _executor.run(
        set,
        cancel: token,
        undoOf: undoOf,
        onProgress: (p) {
          running = RunState(set, p, token);
          onProgress?.call(p);
          notifyListeners();
        },
      );
      return r;
    } finally {
      running = null;
      _suppressChanges = false;
      await refresh(quiet: true);
      notifyListeners();
    }
  }

  void cancelRun() {
    running?.token.cancel();
    notifyListeners();
  }

  ChangeSet undoPlan(JournalEntry e) => Journal.inverse(e, people);

  Future<ExecutionResult?> undo(JournalEntry e) =>
      apply(undoPlan(e), undoOf: e.id);

  Future<void> deleteEntry(String id) async {
    await journal.delete(id);
    notifyListeners();
  }

  Person? byPhoneId(String id) {
    for (final p in people) {
      if (p.phoneId == id) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _changes?.cancel();
    _changeDebounce?.cancel();
    super.dispose();
  }
}

@visibleForTesting
PhoneBook demoPhoneBook(List<Person> seed) => PhoneBook(
  FakeSource(seed: seed, groups: const ['Family', 'Work']),
  Journal(MemoryJournalStore()),
);
