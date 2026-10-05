import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/journal.dart';
import '../state/queue_state.dart';
import '../models/person.dart';

class LibraryStore {
  static const boxName = 'library_v1';
  static const metaBox = 'meta_v1';
  static const schemaKey = 'library_schema';

  Box<String>? _b;
  bool _ready = false;

  Future<void> initHive() async {
    if (_ready) return;
    await Hive.initFlutter();
    _ready = true;
  }

  Future<void> open() async {
    await initHive();
    await openIn();
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
      } catch (_) {}
    }
    await b.putAll(rewrite);
    await meta.put(schemaKey, Person.schemaVersion);
    return upgraded;
  }

  List<Person> load() {
    final b = _b;
    if (b == null) return [];
    final out = <Person>[];
    for (final v in b.values) {
      try {
        out.add(Person.fromJson(jsonDecode(v) as Map));
      } catch (_) {}
    }
    return out;
  }

  Future<void> putAll(Iterable<Person> people) async {
    final b = _b;
    if (b == null) return;
    await b.putAll({for (final p in people) p.id: jsonEncode(p.toJson())});
  }

  Future<void> deleteAll(Iterable<String> ids) async {
    await _b?.deleteAll(ids);
  }

  Future<void> clear() async {
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
