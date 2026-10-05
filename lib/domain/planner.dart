import '../models/person.dart';
import 'change_set.dart';

class Planner {
  static ChangeSet create(Person draft, {AccountRef? account}) => ChangeSet(
    ChangeIntent.create,
    [CreateChange(draft.copy(clearPhoneId: true), account: account)],
  );

  static ChangeSet edit(Person before, Person after) => ChangeSet(
    ChangeIntent.edit,
    [if (!sameContent(before, after)) UpdateChange(before, after)],
  );

  static ChangeSet delete(Iterable<Person> people) =>
      ChangeSet(ChangeIntent.delete, [for (final p in people) DeleteChange(p)]);

  static ChangeSet star(Iterable<Person> people, bool starred) =>
      _transform(ChangeIntent.star, people, (p) => p.starred = starred);

  static ChangeSet group(Iterable<Person> people, String group, bool add) {
    final g = group.trim();
    if (g.isEmpty) return const ChangeSet(ChangeIntent.group, []);
    return _transform(ChangeIntent.group, people, (p) {
      if (add && !p.groups.contains(g)) p.groups.add(g);
      if (!add) p.groups.remove(g);
    });
  }

  static ChangeSet batch(List<Person> originals, List<Person> edited) {
    final byId = {for (final p in originals) p.id: p};
    return ChangeSet(ChangeIntent.batch, [
      for (final e in edited)
        if (byId[e.id] case final before? when !sameContent(before, e))
          UpdateChange(before, e),
    ]);
  }

  static ChangeSet _transform(
    ChangeIntent intent,
    Iterable<Person> people,
    void Function(Person) edit,
  ) {
    final out = <Change>[];
    for (final p in people) {
      final next = p.copy();
      edit(next);
      if (!sameContent(p, next)) out.add(UpdateChange(p, next));
    }
    return ChangeSet(intent, out);
  }
}
