import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/person.dart';

class LibraryStore {
  static const _box = 'library_v1';
  Box<String>? _b;

  Future<void> open() async {
    await Hive.initFlutter();
    _b = await Hive.openBox<String>(_box);
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
