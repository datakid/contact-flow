import 'package:hive/hive.dart';

abstract class TagStore {
  Future<Map<String, String>> loadAll();
  Future<void> putAll(Map<String, String> entries);
  Future<void> removeAll(Iterable<String> keys);
}

class MemoryTagStore implements TagStore {
  final Map<String, String> data = {};

  @override
  Future<Map<String, String>> loadAll() async => Map.of(data);

  @override
  Future<void> putAll(Map<String, String> entries) async =>
      data.addAll(entries);

  @override
  Future<void> removeAll(Iterable<String> keys) async {
    for (final k in keys) {
      data.remove(k);
    }
  }
}

class HiveTagStore implements TagStore {
  static const boxName = 'tags_v1';
  static const schemaKey = 'meta:schema';
  static const schemaVersion = 1;

  Box<String>? _b;

  Future<Box<String>> _box() async {
    final b = _b ??= await Hive.openBox<String>(boxName);
    if (b.get(schemaKey) == null) await b.put(schemaKey, '$schemaVersion');
    return b;
  }

  @override
  Future<Map<String, String>> loadAll() async {
    final b = await _box();
    return {
      for (final k in b.keys)
        if ('$k' != schemaKey && b.get(k) != null) '$k': b.get(k)!,
    };
  }

  @override
  Future<void> putAll(Map<String, String> entries) async =>
      (await _box()).putAll(entries);

  @override
  Future<void> removeAll(Iterable<String> keys) async =>
      (await _box()).deleteAll(keys);
}
