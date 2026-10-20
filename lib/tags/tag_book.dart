import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/person.dart';
import '../phone/phone_key.dart';
import 'tag_models.dart';
import 'tag_store.dart';

class TagUndo {
  final Map<String, Tag?> tags;
  final Map<String, NumberTag?> numbers;
  const TagUndo(this.tags, this.numbers);
}

class TagBook extends ChangeNotifier {
  final TagStore _store;
  final Map<String, Tag> _tags = {};
  final Map<String, NumberTag> _numbers = {};
  final Map<String, Set<String>> _byKey = {};
  final Random _rand = Random();

  TagBook(this._store);

  static const palette = [
    0xFFE8664A,
    0xFF3F8EFC,
    0xFF2BB673,
    0xFFF2A93B,
    0xFF9B5DE5,
    0xFF00A6A6,
    0xFFD6336C,
    0xFF6C757D,
  ];

  Future<void> load() async {
    final all = await _store.loadAll();
    _tags.clear();
    _numbers.clear();
    all.forEach((k, v) {
      try {
        final m = jsonDecode(v) as Map;
        if (k.startsWith('tag:')) {
          final t = Tag.fromJson(m);
          _tags[t.id] = t;
        } else if (k.startsWith('nt:')) {
          final n = NumberTag.fromJson(m);
          _numbers[n.storageKey] = n;
        }
      } catch (_) {}
    });
    _numbers.removeWhere((_, n) => !_tags.containsKey(n.tagId));
    _reindex();
    notifyListeners();
  }

  void _reindex() {
    _byKey.clear();
    for (final n in _numbers.values) {
      (_byKey[n.key] ??= {}).add(n.tagId);
    }
  }

  List<Tag> get tags =>
      _tags.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Tag? byId(String id) => _tags[id];

  Tag? byName(String name) {
    final n = name.trim().toLowerCase();
    for (final t in _tags.values) {
      if (t.name.toLowerCase() == n) return t;
    }
    return null;
  }

  String _newId() =>
      't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_rand.nextInt(1 << 20).toRadixString(36)}';

  Future<void> _persist(TagUndo changes) async {
    final put = <String, String>{};
    final remove = <String>[];
    changes.tags.forEach((id, t) {
      if (t == null) {
        remove.add('tag:$id');
      } else {
        put['tag:$id'] = jsonEncode(t.toJson());
      }
    });
    changes.numbers.forEach((k, n) {
      if (n == null) {
        remove.add(k);
      } else {
        put[k] = jsonEncode(n.toJson());
      }
    });
    if (put.isNotEmpty) await _store.putAll(put);
    if (remove.isNotEmpty) await _store.removeAll(remove);
  }

  Future<TagUndo> _apply(
    Map<String, Tag?> tagChanges,
    Map<String, NumberTag?> numberChanges,
  ) async {
    final before = TagUndo(
      {for (final id in tagChanges.keys) id: _tags[id]},
      {for (final k in numberChanges.keys) k: _numbers[k]},
    );
    tagChanges.forEach((id, t) {
      if (t == null) {
        _tags.remove(id);
      } else {
        _tags[id] = t;
      }
    });
    numberChanges.forEach((k, n) {
      if (n == null) {
        _numbers.remove(k);
      } else {
        _numbers[k] = n;
      }
    });
    _reindex();
    await _persist(TagUndo(tagChanges, numberChanges));
    notifyListeners();
    return before;
  }

  Future<void> undo(TagUndo u) async {
    await _apply(u.tags, u.numbers);
  }

  Future<Tag> create(String name, {int? colour}) async {
    final clean = name.trim();
    final existing = byName(clean);
    if (existing != null) return existing;
    final t = Tag(
      id: _newId(),
      name: clean,
      colour: colour ?? palette[_tags.length % palette.length],
      created: DateTime.now().millisecondsSinceEpoch,
    );
    await _apply({t.id: t}, const {});
    return t;
  }

  Future<bool> rename(String id, String name) async {
    final t = _tags[id];
    final clean = name.trim();
    if (t == null || clean.isEmpty) return false;
    final clash = byName(clean);
    if (clash != null && clash.id != id) return false;
    await _apply({id: t.copyWith(name: clean)}, const {});
    return true;
  }

  Future<void> recolour(String id, int colour) async {
    final t = _tags[id];
    if (t == null) return;
    await _apply({id: t.copyWith(colour: colour)}, const {});
  }

  Future<TagUndo> delete(String id) async {
    final gone = {
      for (final n in _numbers.values)
        if (n.tagId == id) n.storageKey: null,
    };
    return _apply({id: null}, gone);
  }

  Future<TagUndo> merge(String fromId, String intoId) async {
    if (fromId == intoId || !_tags.containsKey(intoId)) {
      return const TagUndo({}, {});
    }
    final changes = <String, NumberTag?>{};
    for (final n in _numbers.values.where((n) => n.tagId == fromId)) {
      changes[n.storageKey] = null;
      final moved = n.copyWith(tagId: intoId);
      if (!_numbers.containsKey(moved.storageKey)) {
        changes[moved.storageKey] = moved;
      }
    }
    return _apply({fromId: null}, changes);
  }

  Future<int> assign(Iterable<String> tagIds, Iterable<String> numbers) async {
    final changes = <String, NumberTag?>{};
    for (final raw in numbers) {
      final key = TagKey.of(raw);
      if (key.isEmpty) continue;
      for (final id in tagIds) {
        if (!_tags.containsKey(id)) continue;
        final n = NumberTag(
          key: key,
          raw: raw,
          region: PhoneKey.regionCode,
          tagId: id,
        );
        if (!_numbers.containsKey(n.storageKey)) changes[n.storageKey] = n;
      }
    }
    if (changes.isEmpty) return 0;
    await _apply(const {}, changes);
    return changes.length;
  }

  Future<int> unassign(Iterable<String> tagIds, Iterable<String> numbers) async {
    final changes = <String, NumberTag?>{};
    for (final raw in numbers) {
      final key = TagKey.of(raw);
      for (final id in tagIds) {
        final k = 'nt:$id|$key';
        if (_numbers.containsKey(k)) changes[k] = null;
      }
    }
    if (changes.isEmpty) return 0;
    await _apply(const {}, changes);
    return changes.length;
  }

  Set<String> tagIdsForNumber(String raw) {
    final key = TagKey.of(raw);
    return key.isEmpty ? const {} : (_byKey[key] ?? const {});
  }

  List<Tag> tagsForNumber(String raw) => [
    for (final id in tagIdsForNumber(raw))
      if (_tags[id] != null) _tags[id]!,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Tag> tagsForPerson(Person p) {
    final ids = <String>{};
    for (final e in p.phones) {
      ids.addAll(tagIdsForNumber(e.number));
    }
    return [
      for (final id in ids)
        if (_tags[id] != null) _tags[id]!,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool personHasTag(Person p, String name) {
    final t = byName(name);
    if (t == null) return false;
    for (final e in p.phones) {
      if (tagIdsForNumber(e.number).contains(t.id)) return true;
    }
    return false;
  }

  int count(String tagId) =>
      _numbers.values.where((n) => n.tagId == tagId).length;

  List<NumberTag> numbersFor(String tagId) => [
    for (final n in _numbers.values)
      if (n.tagId == tagId) n,
  ];

  Future<int> rekeyUnparsed() async {
    final changes = <String, NumberTag?>{};
    for (final n in _numbers.values) {
      if (!TagKey.isUnparsed(n.key)) continue;
      final key = TagKey.of(n.raw);
      if (key.isEmpty || key == n.key) continue;
      final moved = n.copyWith(key: key, region: PhoneKey.regionCode);
      changes[n.storageKey] = null;
      if (!_numbers.containsKey(moved.storageKey)) {
        changes[moved.storageKey] = moved;
      }
    }
    if (changes.isEmpty) return 0;
    await _apply(const {}, changes);
    return changes.values.where((v) => v != null).length;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'generator': 'Contact Flow',
    'version': 1,
    'tags': [for (final t in tags) t.toJson()],
    'numbers': [for (final n in _numbers.values) n.toJson()],
  });

  Future<int> importJson(String text) async {
    final root = jsonDecode(text) as Map;
    final idMap = <String, String>{};
    for (final raw in (root['tags'] as List? ?? const [])) {
      final t = Tag.fromJson(raw as Map);
      final made = await create(t.name, colour: t.colour);
      idMap[t.id] = made.id;
    }
    var added = 0;
    for (final raw in (root['numbers'] as List? ?? const [])) {
      final n = NumberTag.fromJson(raw as Map);
      final id = idMap[n.tagId];
      if (id == null) continue;
      added += await assign([id], [n.raw]);
    }
    return added;
  }
}
