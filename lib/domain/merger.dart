import '../models/person.dart';
import 'change_set.dart';
import 'names.dart';

enum DuplicateReason { sharedNumber, sameName }

class DuplicateGroup {
  final List<Person> people;
  final Set<DuplicateReason> reasons;
  final String evidence;
  const DuplicateGroup(this.people, this.reasons, this.evidence);
}

class Merger {
  static List<PhoneEntry> unionPhones(Iterable<List<PhoneEntry>> lists) {
    final seen = <String>{};
    final out = <PhoneEntry>[];
    for (final list in lists) {
      for (final e in list) {
        final k = Phones.key(e.number);
        final id = k.isEmpty ? Phones.digits(e.number) : k;
        if (id.isEmpty || !seen.add(id)) continue;
        out.add(PhoneEntry(e.number.trim(), e.label));
      }
    }
    return out;
  }

  static List<String> unionEmails(Iterable<List<String>> lists) {
    final seen = <String>{};
    return [
      for (final list in lists)
        for (final e in list)
          if (e.trim().isNotEmpty && seen.add(e.trim().toLowerCase())) e.trim(),
    ];
  }

  static String unionNotes(Iterable<String> notes) {
    final seen = <String>{};
    final lines = <String>[];
    for (final n in notes) {
      for (final line in n.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty && seen.add(t.toLowerCase())) lines.add(t);
      }
    }
    return lines.join('\n');
  }

  static String _first(Iterable<String> values) => values
      .map((v) => v.trim())
      .firstWhere((v) => v.isNotEmpty, orElse: () => '');

  static Person combine(Person keep, List<Person> others) {
    final all = [keep, ...others];
    final out = keep.copy();
    out.name = _first(all.map((p) => p.name));
    out.aliases = Aliases.union([
      for (final p in all) p.aliases,
      [for (final p in all) p.name],
    ], name: out.name);
    out.org = _first(all.map((p) => p.org));
    out.jobTitle = _first(all.map((p) => p.jobTitle));
    out.phones = unionPhones(all.map((p) => p.phones));
    out.emails = unionEmails(all.map((p) => p.emails));
    out.note = unionNotes(all.map((p) => p.note));
    out.starred = all.any((p) => p.starred);
    final groups = <String>{};
    out.groups = [
      for (final p in all)
        for (final g in p.groups)
          if (groups.add(g)) g,
    ];
    return out;
  }

  static MergeChange plan(Person keep, List<Person> others) =>
      MergeChange(keep, combine(keep, others), others);

  static ChangeSet planAll(
    List<DuplicateGroup> groups, {
    Map<int, String>? keepIds,
  }) {
    final out = <Change>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final keepId = keepIds?[i];
      final keep = g.people.firstWhere(
        (p) => p.id == keepId,
        orElse: () => suggestKeep(g.people),
      );
      out.add(
        plan(keep, [
          for (final p in g.people)
            if (p.id != keep.id) p,
        ]),
      );
    }
    return ChangeSet(ChangeIntent.merge, out);
  }

  static int _richness(Person p) =>
      (p.name.trim().isNotEmpty ? 4 : 0) +
      p.phones.length * 2 +
      p.emails.length +
      (p.org.isNotEmpty ? 1 : 0) +
      (p.note.isNotEmpty ? 1 : 0) +
      (p.aliases.isNotEmpty ? 1 : 0) +
      (p.starred ? 3 : 0);

  static Person suggestKeep(List<Person> people) {
    var best = people.first;
    for (final p in people.skip(1)) {
      if (_richness(p) > _richness(best)) best = p;
    }
    return best;
  }

  static List<DuplicateGroup> findDuplicates(List<Person> people) {
    final parent = List<int>.generate(people.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    final links = <_Link>[];
    void join(int a, int b, DuplicateReason reason, String why) {
      links.add(_Link(a, reason, why));
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    final firstByKey = <String, int>{};
    final firstByName = <String, int>{};
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      for (final e in p.phones) {
        final k = Phones.key(e.number);
        if (k.isEmpty) continue;
        final j = firstByKey[k];
        if (j == null) {
          firstByKey[k] = i;
        } else if (j != i) {
          join(j, i, DuplicateReason.sharedNumber, e.number.trim());
        }
      }
      final n = NameParts.normalized(p.name);
      if (n.isEmpty) continue;
      final j = firstByName[n];
      if (j == null) {
        firstByName[n] = i;
      } else {
        join(j, i, DuplicateReason.sameName, p.name.trim());
      }
    }
    final members = <int, List<Person>>{};
    for (var i = 0; i < people.length; i++) {
      (members[find(i)] ??= []).add(people[i]);
    }
    final reasons = <int, Set<DuplicateReason>>{};
    final evidence = <int, String>{};
    for (final l in links) {
      final root = find(l.anchor);
      (reasons[root] ??= {}).add(l.reason);
      evidence.putIfAbsent(root, () => l.why);
    }
    final out = <DuplicateGroup>[
      for (final e in members.entries)
        if (e.value.length > 1)
          DuplicateGroup(e.value, reasons[e.key] ?? {}, evidence[e.key] ?? ''),
    ];
    out.sort(
      (a, b) =>
          a.people.first.displayName.compareTo(b.people.first.displayName),
    );
    return out;
  }
}

class _Link {
  final int anchor;
  final DuplicateReason reason;
  final String why;
  const _Link(this.anchor, this.reason, this.why);
}
