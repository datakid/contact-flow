import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../tags/tag_models.dart';
import '../tags/tag_store.dart';

class IgnoreBook extends ChangeNotifier {
  final TagStore _store;
  final Map<String, String> _raw = {};
  IgnoreBook(this._store);

  Set<String> get keys => _raw.keys.toSet();

  List<MapEntry<String, String>> get entries =>
      _raw.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

  bool has(String key) => _raw.containsKey(key);

  Future<void> load() async {
    _raw.clear();
    final all = await _store.loadAll();
    all.forEach((k, v) {
      if (!k.startsWith('ig:')) return;
      try {
        final m = jsonDecode(v) as Map;
        _raw['${m['key']}'] = '${m['raw'] ?? ''}';
      } catch (_) {}
    });
    notifyListeners();
  }

  Future<List<String>> add(Iterable<String> numbers) async {
    final added = <String>[];
    final put = <String, String>{};
    for (final n in numbers) {
      final key = TagKey.of(n);
      if (key.isEmpty || _raw.containsKey(key)) continue;
      _raw[key] = n;
      added.add(key);
      put['ig:$key'] = jsonEncode({'key': key, 'raw': n});
    }
    if (put.isNotEmpty) await _store.putAll(put);
    notifyListeners();
    return added;
  }

  Future<void> addKeys(Map<String, String> keyToRaw) async {
    final put = <String, String>{};
    keyToRaw.forEach((key, raw) {
      if (_raw.containsKey(key)) return;
      _raw[key] = raw;
      put['ig:$key'] = jsonEncode({'key': key, 'raw': raw});
    });
    if (put.isNotEmpty) await _store.putAll(put);
    notifyListeners();
  }

  Future<void> remove(Iterable<String> keys) async {
    final gone = [
      for (final k in keys)
        if (_raw.remove(k) != null) 'ig:$k',
    ];
    if (gone.isNotEmpty) await _store.removeAll(gone);
    notifyListeners();
  }
}
