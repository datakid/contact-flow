import '../models/person.dart';
import 'change_set.dart';
import 'matcher.dart';
import 'merger.dart';

enum FieldPolicy { fillEmpty, overwrite, addNumbers }

class SyncUpdate {
  final ContactMatch match;
  final Person after;
  const SyncUpdate(this.match, this.after);
  Person get before => match.target;
  List<FieldChange> get fields => diffFields(before, after);
}

class SyncPlan {
  final FieldPolicy policy;
  final List<Person> fresh;
  final List<SyncUpdate> updates;
  final List<ContactMatch> unchanged;
  final List<Conflict> conflicts;
  final List<Person> onlyOnPhone;
  const SyncPlan(
    this.policy,
    this.fresh,
    this.updates,
    this.unchanged,
    this.conflicts,
    this.onlyOnPhone,
  );
}

class SyncChoices {
  final Set<int> skipFresh;
  final Set<int> skipUpdates;
  final Map<int, String> conflictTargets;
  final Set<String> deleteOnlyOnPhone;
  const SyncChoices({
    this.skipFresh = const {},
    this.skipUpdates = const {},
    this.conflictTargets = const {},
    this.deleteOnlyOnPhone = const {},
  });
}

class SyncJob {
  final List<Person> phone;
  final List<Person> rows;
  final FieldPolicy policy;
  const SyncJob(this.phone, this.rows, this.policy);
}

SyncPlan runSyncPlan(SyncJob j) => SyncPlanner.plan(j.phone, j.rows, j.policy);

class SyncPlanner {
  static List<PhoneEntry> _copyPhones(List<PhoneEntry> list) =>
      list.map((e) => PhoneEntry(e.number.trim(), e.label)).toList();

  static Person applyPolicy(Person target, Person row, FieldPolicy policy) {
    final out = target.copy();
    String pick(String mine, String theirs) {
      final t = theirs.trim();
      return switch (policy) {
        FieldPolicy.overwrite => t.isEmpty ? mine : t,
        _ => mine.trim().isEmpty ? t : mine,
      };
    }

    out.name = pick(out.name, row.name);
    out.org = pick(out.org, row.org);
    out.jobTitle = pick(out.jobTitle, row.jobTitle);
    switch (policy) {
      case FieldPolicy.overwrite:
        out.note = pick(out.note, row.note);
        if (row.phones.isNotEmpty) out.phones = _copyPhones(row.phones);
        if (row.emails.isNotEmpty) out.emails = [...row.emails];
      case FieldPolicy.fillEmpty:
        out.note = pick(out.note, row.note);
        if (out.phones.isEmpty) out.phones = _copyPhones(row.phones);
        if (out.emails.isEmpty) out.emails = [...row.emails];
      case FieldPolicy.addNumbers:
        out.phones = Merger.unionPhones([out.phones, row.phones]);
        out.emails = Merger.unionEmails([out.emails, row.emails]);
        out.note = Merger.unionNotes([out.note, row.note]);
    }
    return out;
  }

  static SyncPlan plan(
    List<Person> phone,
    List<Person> rows,
    FieldPolicy policy,
  ) {
    final result = ContactMatcher(phone).match(rows);
    final updates = <SyncUpdate>[];
    final unchanged = <ContactMatch>[];
    for (final m in result.matched) {
      final after = applyPolicy(m.target, m.row, policy);
      if (sameContent(m.target, after)) {
        unchanged.add(m);
      } else {
        updates.add(SyncUpdate(m, after));
      }
    }
    return SyncPlan(
      policy,
      result.unmatched,
      updates,
      unchanged,
      result.conflicts,
      result.onlyOnPhone,
    );
  }

  static ChangeSet toChangeSet(
    SyncPlan plan,
    SyncChoices choices, {
    AccountRef? account,
  }) {
    final out = <Change>[];
    for (var i = 0; i < plan.fresh.length; i++) {
      if (choices.skipFresh.contains(i)) continue;
      out.add(
        CreateChange(plan.fresh[i].copy(clearPhoneId: true), account: account),
      );
    }
    final touched = <String>{};
    for (var i = 0; i < plan.updates.length; i++) {
      if (choices.skipUpdates.contains(i)) continue;
      final u = plan.updates[i];
      touched.add(u.before.id);
      out.add(UpdateChange(u.before, u.after));
    }
    for (final e in choices.conflictTargets.entries) {
      if (e.key < 0 || e.key >= plan.conflicts.length) continue;
      final c = plan.conflicts[e.key];
      final target = c.candidates.where((p) => p.id == e.value).firstOrNull;
      if (target == null || !touched.add(target.id)) continue;
      final after = applyPolicy(target, c.row, plan.policy);
      if (!sameContent(target, after)) out.add(UpdateChange(target, after));
    }
    for (final p in plan.onlyOnPhone) {
      if (choices.deleteOnlyOnPhone.contains(p.id)) out.add(DeleteChange(p));
    }
    return ChangeSet(ChangeIntent.sync, out);
  }
}
