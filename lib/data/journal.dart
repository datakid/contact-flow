import 'dart:convert';

import '../domain/change_set.dart';
import '../io/vcard.dart';
import '../models/person.dart';

enum ResultStatus { ok, failed, skipped }

class ChangeRecord {
  final ChangeKind kind;
  final String label;
  String? phoneId;
  final String? before;
  final List<String> removed;
  final String? account;
  ResultStatus status;
  String error;

  ChangeRecord({
    required this.kind,
    required this.label,
    this.phoneId,
    this.before,
    this.removed = const [],
    this.account,
    this.status = ResultStatus.skipped,
    this.error = '',
  });

  Map<String, dynamic> toJson() => {
    'k': kind.index,
    'l': label,
    if (phoneId != null) 'id': phoneId,
    if (before != null) 'b': before,
    if (removed.isNotEmpty) 'r': removed,
    if (account != null) 'a': account,
    's': status.index,
    if (error.isNotEmpty) 'e': error,
  };

  factory ChangeRecord.fromJson(Map m) => ChangeRecord(
    kind: ChangeKind
        .values[(m['k'] as int).clamp(0, ChangeKind.values.length - 1)],
    label: '${m['l'] ?? ''}',
    phoneId: m['id'] as String?,
    before: m['b'] as String?,
    removed: ((m['r'] as List?) ?? const []).map((e) => '$e').toList(),
    account: m['a'] as String?,
    status: ResultStatus.values[((m['s'] as int?) ?? 2).clamp(0, 2)],
    error: '${m['e'] ?? ''}',
  );
}

enum EntryState { running, done, cancelled }

class JournalEntry {
  final String id;
  final DateTime time;
  final ChangeIntent intent;
  final List<ChangeRecord> records;
  EntryState state;
  DateTime? undoneAt;
  final String? undoOf;

  JournalEntry({
    required this.id,
    required this.time,
    required this.intent,
    required this.records,
    this.state = EntryState.running,
    this.undoneAt,
    this.undoOf,
  });

  int count(ChangeKind k, [ResultStatus s = ResultStatus.ok]) =>
      records.where((r) => r.kind == k && r.status == s).length;

  int get okCount => records.where((r) => r.status == ResultStatus.ok).length;
  int get failedCount =>
      records.where((r) => r.status == ResultStatus.failed).length;
  int get skippedCount =>
      records.where((r) => r.status == ResultStatus.skipped).length;

  bool get canUndo => undoneAt == null && okCount > 0;

  String get backupVcf => [
    for (final r in records) ...[?r.before, ...r.removed],
  ].join();

  int get backupContacts => records.fold(
    0,
    (n, r) => n + (r.before == null ? 0 : 1) + r.removed.length,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    't': time.millisecondsSinceEpoch,
    'i': intent.index,
    'st': state.index,
    if (undoneAt != null) 'u': undoneAt!.millisecondsSinceEpoch,
    if (undoOf != null) 'uo': undoOf,
    'r': records.map((r) => r.toJson()).toList(),
  };

  factory JournalEntry.fromJson(Map m) => JournalEntry(
    id: '${m['id']}',
    time: DateTime.fromMillisecondsSinceEpoch(m['t'] as int),
    intent: ChangeIntent
        .values[(m['i'] as int).clamp(0, ChangeIntent.values.length - 1)],
    state: EntryState.values[((m['st'] as int?) ?? 1).clamp(0, 2)],
    undoneAt: m['u'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['u'] as int)
        : null,
    undoOf: m['uo'] as String?,
    records: ((m['r'] as List?) ?? const [])
        .whereType<Map>()
        .map(ChangeRecord.fromJson)
        .toList(),
  );

  String encode() => jsonEncode(toJson());
}

abstract class JournalStore {
  Future<List<String>> loadAll();
  Future<void> put(String id, String json);
  Future<void> remove(String id);
}

class MemoryJournalStore implements JournalStore {
  final Map<String, String> data = {};
  @override
  Future<List<String>> loadAll() async => data.values.toList();
  @override
  Future<void> put(String id, String json) async => data[id] = json;
  @override
  Future<void> remove(String id) async => data.remove(id);
}

class Journal {
  static const maxEntries = 30;
  static const maxAge = Duration(days: 30);

  final JournalStore store;
  final DateTime Function() clock;
  final List<JournalEntry> _entries = [];
  int _seq = 0;

  Journal(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _entries.clear();
    for (final raw in await store.loadAll()) {
      try {
        final e = JournalEntry.fromJson(jsonDecode(raw) as Map);
        if (e.state == EntryState.running) e.state = EntryState.cancelled;
        _entries.add(e);
      } catch (_) {}
    }
    _entries.sort((a, b) => b.time.compareTo(a.time));
    await prune();
  }

  JournalEntry? byId(String id) =>
      _entries.where((e) => e.id == id).firstOrNull;

  int get storageBytes =>
      _entries.fold(0, (n, e) => n + utf8.encode(e.encode()).length);

  static String snapshot(Person p) => VCard.write([p], lossless: true);

  static Person? restore(String? vcf) {
    if (vcf == null || vcf.isEmpty) return null;
    final list = VCard.parse(vcf, 'backup');
    return list.isEmpty ? null : list.first;
  }

  JournalEntry begin(ChangeSet set, {String? undoOf}) {
    final now = clock();
    final records = [
      for (final c in set.changes)
        switch (c) {
          CreateChange() => ChangeRecord(
            kind: c.kind,
            label: c.after.displayName,
            account: c.account?.key,
          ),
          UpdateChange() => ChangeRecord(
            kind: c.kind,
            label: c.after.displayName,
            phoneId: c.before.phoneId,
            before: snapshot(c.before),
          ),
          DeleteChange() => ChangeRecord(
            kind: c.kind,
            label: c.before.displayName,
            phoneId: c.before.phoneId,
            before: snapshot(c.before),
          ),
          MergeChange() => ChangeRecord(
            kind: c.kind,
            label: c.keepAfter.displayName,
            phoneId: c.keepBefore.phoneId,
            before: snapshot(c.keepBefore),
            removed: c.removed.map(snapshot).toList(),
          ),
        },
    ];
    return JournalEntry(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}',
      time: now,
      intent: set.intent,
      records: records,
      undoOf: undoOf,
    );
  }

  Future<void> save(JournalEntry e) async {
    _entries.removeWhere((x) => x.id == e.id);
    _entries.insert(0, e);
    _entries.sort((a, b) => b.time.compareTo(a.time));
    await store.put(e.id, e.encode());
  }

  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await store.remove(id);
  }

  Future<void> prune() async {
    final now = clock();
    final drop = <String>[];
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (i >= maxEntries || now.difference(e.time) > maxAge) drop.add(e.id);
    }
    for (final id in drop) {
      await delete(id);
    }
  }

  static ChangeSet inverse(JournalEntry e, List<Person> current) {
    final byPhoneId = {
      for (final p in current)
        if (p.phoneId != null) p.phoneId!: p,
    };
    final out = <Change>[];
    for (final r in e.records.reversed) {
      if (r.status != ResultStatus.ok) continue;
      final now = r.phoneId == null ? null : byPhoneId[r.phoneId];
      final before = restore(r.before);
      switch (r.kind) {
        case ChangeKind.create:
          if (now != null) out.add(DeleteChange(now));
        case ChangeKind.update:
          if (before == null) continue;
          if (now != null) {
            final target = before.copy(id: now.id, phoneId: now.phoneId)
              ..account = now.account;
            if (!sameContent(now, target)) out.add(UpdateChange(now, target));
          } else {
            out.add(
              CreateChange(
                before.copy(clearPhoneId: true),
                account: before.account,
              ),
            );
          }
        case ChangeKind.delete:
          if (before != null) {
            out.add(
              CreateChange(
                before.copy(clearPhoneId: true),
                account: before.account,
              ),
            );
          }
        case ChangeKind.merge:
          if (before != null) {
            if (now != null) {
              final target = before.copy(id: now.id, phoneId: now.phoneId)
                ..account = now.account;
              if (!sameContent(now, target)) out.add(UpdateChange(now, target));
            } else {
              out.add(
                CreateChange(
                  before.copy(clearPhoneId: true),
                  account: before.account,
                ),
              );
            }
          }
          for (final raw in r.removed) {
            final p = restore(raw);
            if (p != null) {
              out.add(
                CreateChange(p.copy(clearPhoneId: true), account: p.account),
              );
            }
          }
      }
    }
    return ChangeSet(ChangeIntent.undo, out);
  }
}
