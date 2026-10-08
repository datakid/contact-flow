import '../models/person.dart';

enum ContactField {
  name,
  aliases,
  phones,
  emails,
  company,
  jobTitle,
  note,
  starred,
  groups,
}

class FieldChange {
  final ContactField field;
  final String before;
  final String after;
  const FieldChange(this.field, this.before, this.after);
}

String fieldText(Person p, ContactField f) => switch (f) {
  ContactField.name => p.name.trim(),
  ContactField.aliases => p.cleanAliases.join('\n'),
  ContactField.phones =>
    p.phones.map((e) => '${e.label}\t${e.number.trim()}').join('\n'),
  ContactField.emails => p.emails.map((e) => e.trim()).join('\n'),
  ContactField.company => p.org.trim(),
  ContactField.jobTitle => p.jobTitle.trim(),
  ContactField.note => p.note.trim(),
  ContactField.starred => p.starred ? '1' : '',
  ContactField.groups => ([...p.groups]..sort()).join('\n'),
};

List<FieldChange> diffFields(Person before, Person after) => [
  for (final f in ContactField.values)
    if (fieldText(before, f) != fieldText(after, f))
      FieldChange(f, fieldText(before, f), fieldText(after, f)),
];

bool sameContent(Person a, Person b) => diffFields(a, b).isEmpty;

enum ChangeKind { create, update, delete, merge }

sealed class Change {
  const Change();
  ChangeKind get kind;
  Person get subject;
  Iterable<Person> get touchedBefore;
}

class CreateChange extends Change {
  final Person after;
  final AccountRef? account;
  const CreateChange(this.after, {this.account});
  @override
  ChangeKind get kind => ChangeKind.create;
  @override
  Person get subject => after;
  @override
  Iterable<Person> get touchedBefore => const [];
}

class UpdateChange extends Change {
  final Person before;
  final Person after;
  const UpdateChange(this.before, this.after);
  List<FieldChange> get fields => diffFields(before, after);
  @override
  ChangeKind get kind => ChangeKind.update;
  @override
  Person get subject => after;
  @override
  Iterable<Person> get touchedBefore => [before];
}

class DeleteChange extends Change {
  final Person before;
  const DeleteChange(this.before);
  @override
  ChangeKind get kind => ChangeKind.delete;
  @override
  Person get subject => before;
  @override
  Iterable<Person> get touchedBefore => [before];
}

class MergeChange extends Change {
  final Person keepBefore;
  final Person keepAfter;
  final List<Person> removed;
  const MergeChange(this.keepBefore, this.keepAfter, this.removed);
  List<FieldChange> get fields => diffFields(keepBefore, keepAfter);
  @override
  ChangeKind get kind => ChangeKind.merge;
  @override
  Person get subject => keepAfter;
  @override
  Iterable<Person> get touchedBefore => [keepBefore, ...removed];
}

enum ChangeIntent {
  create,
  edit,
  delete,
  star,
  group,
  batch,
  sync,
  merge,
  undo,
}

class ChangeSet {
  final ChangeIntent intent;
  final List<Change> changes;
  const ChangeSet(this.intent, this.changes);

  bool get isEmpty => changes.isEmpty;
  bool get isNotEmpty => changes.isNotEmpty;
  int get length => changes.length;

  int count(ChangeKind k) => changes.where((c) => c.kind == k).length;

  int get affectedContacts => changes.fold(
    0,
    (n, c) => n + (c is MergeChange ? 1 + c.removed.length : 1),
  );

  Iterable<Person> get deletedContacts sync* {
    for (final c in changes) {
      if (c is DeleteChange) yield c.before;
      if (c is MergeChange) yield* c.removed;
    }
  }

  bool get deletesFromSyncedAccount =>
      deletedContacts.any((p) => p.account?.isSynced ?? false);

  ChangeSet where(bool Function(int index, Change c) keep) =>
      ChangeSet(intent, [
        for (var i = 0; i < changes.length; i++)
          if (keep(i, changes[i])) changes[i],
      ]);
}
