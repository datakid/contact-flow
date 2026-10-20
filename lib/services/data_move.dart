import 'dart:convert';

import '../calls/ignore_book.dart';
import '../io/codec.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import '../tags/tag_book.dart';

class MoveResult {
  final int people;
  final int tags;
  final int ignored;
  const MoveResult(this.people, this.tags, this.ignored);
}

class DataMove {
  static String export({
    required Iterable<Person> people,
    required TagBook tags,
    required IgnoreBook ignore,
  }) => const JsonEncoder.withIndent('  ').convert({
    'generator': 'Contact Flow',
    'kind': 'move',
    'version': 1,
    'people': [for (final p in people) p.toJson()],
    'tags': jsonDecode(tags.exportJson()),
    'ignore': [
      for (final e in ignore.entries) {'key': e.key, 'raw': e.value},
    ],
  });

  static Future<MoveResult> import(
    String text, {
    required AppState state,
    required TagBook tags,
    required IgnoreBook ignore,
  }) async {
    final Object? root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Not a Contact Flow data export');
    }
    if (root is! Map || root['kind'] != 'move') {
      throw const FormatException('Not a Contact Flow data export');
    }
    final people = [
      for (final m in (root['people'] as List? ?? const []))
        Person.fromJson(m as Map),
    ];
    var added = 0;
    if (people.isNotEmpty) {
      final plan = state.plan([ImportResult(people, Format.json, '')]);
      added = await state.commit(plan, merge: true);
    }
    final addedTags = root['tags'] == null
        ? 0
        : await tags.importJson(jsonEncode(root['tags']));
    final before = ignore.keys.length;
    await ignore.addKeys({
      for (final e in (root['ignore'] as List? ?? const []))
        '${(e as Map)['key']}': '${e['raw'] ?? ''}',
    });
    return MoveResult(added, addedTags, ignore.keys.length - before);
  }
}
