import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/journal.dart';
import '../state/queue_state.dart';
import '../models/person.dart';

class LibraryStore {
  static const boxName = 'library_v1';
  static const metaBox = 'meta_v1';
  static const schemaKey = 'library_schema';

  static const quarantineBox = 'quarantine_v1';

  Box<String>? _b;
  Box<String>? _q;
  bool _ready = false;
  final Map<String, String> _bad = {};

  bool failed = false;
  Object? error;

  Future<void> initHive() async {
    if (_ready) return;
    await Hive.initFlutter();
    _ready = true;
  }

  Future<void> open() async {
    try {
      await initHive();
      await openIn();
      failed = false;
      error = null;
    } catch (e) {
      failed = true;
      error = e;
      rethrow;
    }
  }

  Future<Box<String>> _quarantine() async =>
      _q ??= await Hive.openBox<String>(quarantineBox);

  void _require() {
    if (failed) throw StateError('The library could not be opened: $error');
  }

  Future<int> quarantineBad() async {
    if (_bad.isEmpty) return 0;
    final q = await _quarantine();
    final n = _bad.length;
    await q.putAll({for (final e in _bad.entries) 'library:${e.key}': e.value});
    await _b?.deleteAll(_bad.keys);
    _bad.clear();
    return n;
  }

  Future<int> quarantineCount() async => (await _quarantine()).length;

  Future<String> quarantineJson() async {
    final q = await _quarantine();
    return const JsonEncoder.withIndent('  ').convert({
      'generator': 'Contact Flow',
      'items': [
        for (final k in q.keys) {'key': '$k', 'raw': q.get(k)},
      ],
    });
  }

  Future<void> openIn() async {
    _b = await Hive.openBox<String>(boxName);
    await migrate();
  }

  Future<int> migrate() async {
    final b = _b;
    if (b == null) return 0;
    final meta = await Hive.openBox<int>(metaBox);
    final from = meta.get(schemaKey) ?? 1;
    if (from >= Person.schemaVersion) return 0;
    var upgraded = 0;
    final rewrite = <String, String>{};
    for (final key in b.keys) {
      final raw = b.get(key);
      if (raw == null) continue;
      try {
        final p = Person.fromJson(jsonDecode(raw) as Map);
        rewrite['$key'] = jsonEncode(p.toJson());
        upgraded++;
      } catch (_) {
        _bad['$key'] = raw;
      }
    }
    await b.putAll(rewrite);
    await quarantineBad();
    await meta.put(schemaKey, Person.schemaVersion);
    return upgraded;
  }

  List<Person> load() {
    final b = _b;
    if (b == null) return [];
    final out = <Person>[];
    for (final key in b.keys) {
      final raw = b.get(key);
      if (raw == null) continue;
      try {
        out.add(Person.fromJson(jsonDecode(raw) as Map));
      } catch (_) {
        _bad['$key'] = raw;
      }
    }
    return out;
  }

  Future<void> putAll(Iterable<Person> people) async {
    _require();
    final b = _b;
    if (b == null) return;
    await b.putAll({for (final p in people) p.id: jsonEncode(p.toJson())});
  }

  Future<void> deleteAll(Iterable<String> ids) async {
    _require();
    await _b?.deleteAll(ids);
  }

  Future<void> clear() async {
    _require();
    await _b?.clear();
  }
}

class HiveJournalStore implements JournalStore {
  static const boxName = 'journal_v1';
  Box<String>? _b;

  Future<Box<String>> _box() async =>
      _b ??= await Hive.openBox<String>(boxName);

  @override
  Future<List<String>> loadAll() async => (await _box()).values.toList();

  @override
  Future<void> put(String id, String json) async =>
      (await _box()).put(id, json);

  @override
  Future<void> remove(String id) async => (await _box()).delete(id);

  @override
  Future<void> quarantine(String raw) async {
    final b = await _box();
    final q = await Hive.openBox<String>(LibraryStore.quarantineBox);
    final keys = [
      for (final k in b.keys)
        if (b.get(k) == raw) k,
    ];
    if (keys.isEmpty) {
      await q.put('journal:${raw.hashCode}', raw);
      return;
    }
    for (final k in keys) {
      await q.put('journal:$k', raw);
      await b.delete(k);
    }
  }
}

class HiveKeyValue implements KeyValue {
  static const boxName = 'state_v1';
  Box<String>? _b;

  Future<Box<String>> _box() async =>
      _b ??= await Hive.openBox<String>(boxName);

  @override
  Future<String?> get(String key) async => (await _box()).get(key);

  @override
  Future<void> put(String key, String value) async =>
      (await _box()).put(key, value);

  @override
  Future<void> remove(String key) async => (await _box()).delete(key);
}
