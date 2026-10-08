import '../models/person.dart';
import 'names.dart';

enum MatchReason { contactId, number, name }

enum ConflictReason { sharedNumber, sameName, severalCandidates, claimedTwice }

class ContactMatch {
  final Person row;
  final Person target;
  final MatchReason reason;
  const ContactMatch(this.row, this.target, this.reason);
}

class Conflict {
  final Person row;
  final List<Person> candidates;
  final ConflictReason reason;
  const Conflict(this.row, this.candidates, this.reason);
}

class MatchResult {
  final List<ContactMatch> matched;
  final List<Person> unmatched;
  final List<Conflict> conflicts;
  final List<Person> onlyOnPhone;
  const MatchResult(
    this.matched,
    this.unmatched,
    this.conflicts,
    this.onlyOnPhone,
  );
}

class ContactMatcher {
  final List<Person> phone;
  final Map<String, Person> _byPhoneId = {};
  final Map<String, List<Person>> _byKey = {};
  final Map<String, List<Person>> _byName = {};
  final Map<String, List<Person>> _byAlias = {};

  ContactMatcher(this.phone) {
    for (final p in phone) {
      final id = p.phoneId;
      if (id != null) _byPhoneId[id] = p;
      for (final k in p.phoneKeys) {
        (_byKey[k] ??= []).add(p);
      }
      final n = NameParts.normalized(p.name);
      if (n.isNotEmpty) (_byName[n] ??= []).add(p);
      for (final a in p.cleanAliases) {
        final k = NameParts.normalized(a);
        if (k.isNotEmpty && k != n) (_byAlias[k] ??= []).add(p);
      }
    }
  }

  MatchResult match(List<Person> rows) {
    final rowsPerKey = <String, int>{};
    for (final r in rows) {
      for (final k in r.phoneKeys) {
        rowsPerKey[k] = (rowsPerKey[k] ?? 0) + 1;
      }
    }
    final proposals = <_Proposal>[];
    final unmatched = <Person>[];
    final conflicts = <Conflict>[];
    for (final row in rows) {
      final outcome = _matchRow(row, rowsPerKey);
      switch (outcome) {
        case _Proposal():
          proposals.add(outcome);
        case Conflict():
          conflicts.add(outcome);
        case null:
          unmatched.add(row);
      }
    }
    final claims = <String, List<_Proposal>>{};
    for (final pr in proposals) {
      (claims[pr.target.id] ??= []).add(pr);
    }
    final matched = <ContactMatch>[];
    for (final group in claims.values) {
      final byId = group.where((g) => g.reason == MatchReason.contactId);
      if (group.length == 1) {
        matched.add(
          ContactMatch(group.first.row, group.first.target, group.first.reason),
        );
      } else if (byId.length == 1) {
        final winner = byId.first;
        matched.add(ContactMatch(winner.row, winner.target, winner.reason));
        for (final loser in group.where((g) => !identical(g, winner))) {
          conflicts.add(
            Conflict(loser.row, [loser.target], ConflictReason.claimedTwice),
          );
        }
      } else {
        for (final g in group) {
          conflicts.add(
            Conflict(g.row, [g.target], ConflictReason.claimedTwice),
          );
        }
      }
    }
    final used = {for (final m in matched) m.target.id};
    for (final c in conflicts) {
      for (final cand in c.candidates) {
        used.add(cand.id);
      }
    }
    final onlyOnPhone = [
      for (final p in phone)
        if (!used.contains(p.id)) p,
    ];
    final order = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    matched.sort((a, b) => order[a.row]!.compareTo(order[b.row]!));
    conflicts.sort((a, b) => order[a.row]!.compareTo(order[b.row]!));
    return MatchResult(matched, unmatched, conflicts, onlyOnPhone);
  }

  Object? _matchRow(Person row, Map<String, int> rowsPerKey) {
    final id = row.phoneId;
    if (id != null && id.isNotEmpty) {
      final hit = _byPhoneId[id];
      if (hit != null) return _Proposal(row, hit, MatchReason.contactId);
    }
    final name = NameParts.normalized(row.name);
    final byUniqueKey = <String, Person>{};
    final shared = <String, Person>{};
    for (final k in row.phoneKeys) {
      final owners = _byKey[k];
      if (owners == null) continue;
      final uniqueOnPhone = owners.length == 1;
      final uniqueInFile = (rowsPerKey[k] ?? 0) == 1;
      for (final o in owners) {
        if (uniqueOnPhone && uniqueInFile) {
          byUniqueKey[o.id] = o;
        } else {
          shared[o.id] = o;
        }
      }
    }
    if (byUniqueKey.length == 1) {
      return _Proposal(row, byUniqueKey.values.first, MatchReason.number);
    }
    if (byUniqueKey.length > 1) {
      return Conflict(
        row,
        byUniqueKey.values.toList(),
        ConflictReason.severalCandidates,
      );
    }
    if (shared.isNotEmpty) {
      final sameName = name.isEmpty
          ? const <Person>[]
          : shared.values
                .where((p) => NameParts.normalized(p.name) == name)
                .toList();
      if (sameName.length == 1) {
        return _Proposal(row, sameName.first, MatchReason.number);
      }
      return Conflict(row, shared.values.toList(), ConflictReason.sharedNumber);
    }
    if (name.isEmpty) return null;
    var named = _byName[name];
    if (named == null || named.isEmpty) {
      named = _byAlias[name];
      if (named == null || named.isEmpty) return null;
    }
    if (named.length == 1) return _Proposal(row, named.first, MatchReason.name);
    return Conflict(row, [...named], ConflictReason.sameName);
  }
}

class _Proposal {
  final Person row;
  final Person target;
  final MatchReason reason;
  const _Proposal(this.row, this.target, this.reason);
}
