import '../models/person.dart';
import 'tag_book.dart';

class GroupTagPlan {
  final String name;
  final List<Person> people;
  const GroupTagPlan(this.name, this.people);

  int get contacts => people.length;

  int get numbers => people.fold(0, (a, p) => a + p.phones.length);
}

class GroupTagImport {
  static List<GroupTagPlan> plan(Iterable<Person> people) {
    final byName = <String, List<Person>>{};
    for (final p in people) {
      for (final g in p.groups) {
        final name = g.trim();
        if (name.isEmpty) continue;
        (byName[name] ??= []).add(p);
      }
    }
    return [
      for (final e in byName.entries) GroupTagPlan(e.key, e.value),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static Future<int> apply(TagBook book, Iterable<GroupTagPlan> chosen) async {
    var added = 0;
    for (final g in chosen) {
      final tag = await book.create(g.name);
      final numbers = [
        for (final p in g.people)
          for (final e in p.phones) e.number,
      ];
      added += await book.assign([tag.id], numbers);
    }
    return added;
  }
}
