import 'package:contact_flow/data/contact_source.dart';
import 'package:contact_flow/data/executor.dart';
import 'package:contact_flow/data/journal.dart';
import 'package:contact_flow/domain/change_set.dart';
import 'package:contact_flow/domain/merger.dart';
import 'package:contact_flow/domain/planner.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

const google = AccountRef('me@gmail.com', 'com.google');

List<Person> seed() => [
  Person(
    name: 'Amelia Hart',
    phones: [const PhoneEntry('+44 7700 900461')],
    emails: ['amelia@hart.studio'],
    org: 'Hart Studio',
    jobTitle: 'Founder',
    note: 'line one\nline two; with, punctuation',
    starred: true,
    groups: ['Work', 'VIP'],
    account: google,
  ),
  Person(name: 'محمد عبد الله', phones: [const PhoneEntry('+966 50 123 4567')]),
  Person(name: '王伟', phones: [const PhoneEntry('+86 138 0013 8000', 'work')]),
  Person(
    name: '',
    org: 'Front Desk',
    phones: [const PhoneEntry('+971 4 555 0000')],
  ),
  Person(name: 'Ali Hassan', phones: [const PhoneEntry('+971 50 111 2222')]),
  Person(
    name: 'Ali H',
    phones: [const PhoneEntry('050 111 2222')],
    emails: ['ali@x.com'],
  ),
];

String fingerprint(Iterable<Person> people) {
  final lines = [
    for (final p in people)
      [
        for (final f in ContactField.values) fieldText(p, f),
        p.account?.key ?? '',
      ].join('|'),
  ]..sort();
  return lines.join('\n');
}

class Rig {
  final FakeSource source;
  final Journal journal;
  final Executor executor;
  Rig._(this.source, this.journal) : executor = Executor(source, journal);

  factory Rig({Set<String>? failOn, DateTime Function()? clock}) {
    final s = FakeSource(seed: seed(), failOn: failOn);
    return Rig._(s, Journal(MemoryJournalStore(), clock: clock));
  }

  Future<List<Person>> all() => source.readAll();

  Future<Person> named(String n) async =>
      (await all()).firstWhere((p) => p.displayName == n);

  Future<ExecutionResult> undo(ExecutionResult r) async {
    final inverse = Journal.inverse(r.entry, await all());
    return executor.run(inverse, undoOf: r.entry.id);
  }
}

class SpySource extends FakeSource {
  final Journal journal;
  final List<int> backupsSeenAtWrite = [];
  SpySource(this.journal, Iterable<Person> seed) : super(seed: seed);

  void _spy() {
    final e = journal.entries.isEmpty ? null : journal.entries.first;
    backupsSeenAtWrite.add(e?.backupContacts ?? -1);
  }

  @override
  Future<void> update(Person p) {
    _spy();
    return super.update(p);
  }

  @override
  Future<void> delete(String phoneId) {
    _spy();
    return super.delete(phoneId);
  }
}

void main() {
  test('vCard snapshot round-trips every managed field', () {
    for (final p in seed()) {
      final withId = p.copy(phoneId: 'id-1');
      final back = Journal.restore(Journal.snapshot(withId))!;
      expect(fingerprint([back]), fingerprint([withId]), reason: p.displayName);
      expect(back.phoneId, 'id-1');
    }
  });

  test('snapshot is stored before any write', () async {
    final journal = Journal(MemoryJournalStore());
    final source = SpySource(journal, seed());
    final people = await source.readAll();
    final set = Planner.delete(people.take(3));
    await Executor(source, journal).run(set);
    expect(source.backupsSeenAtWrite, [3, 3, 3]);
    final entry = journal.entries.single;
    expect(entry.backupVcf, contains('BEGIN:VCARD'));
    expect(RegExp('BEGIN:VCARD').allMatches(entry.backupVcf).length, 3);
  });

  test(
    'a failure on one contact is recorded and does not stop the rest',
    () async {
      final rig = Rig(failOn: {'王伟'});
      final people = await rig.all();
      final set = Planner.star(people, true);
      final r = await rig.executor.run(set);
      expect(r.failed, 1);
      expect(r.ok, set.length - 1);
      final failed = r.entry.records.firstWhere(
        (x) => x.status == ResultStatus.failed,
      );
      expect(failed.label, '王伟');
      expect(failed.error, isNotEmpty);
      expect(
        (await rig.all()).where((p) => p.starred).length,
        people.length - 1,
      );
    },
  );

  test(
    'contacts deleted meanwhile and read-only accounts fail gracefully',
    () async {
      final rig = Rig();
      final people = await rig.all();
      final gone = people.first;
      rig.source.removeBehindTheScenes(gone.phoneId!);
      rig.source.readOnlyAccounts.add(google.key);
      final r = await rig.executor.run(Planner.delete(people));
      expect(r.failed, 1);
      expect(r.entry.records.first.error, 'gone');
      expect(rig.source.size, 0);
    },
  );

  test(
    'cancel mid-run stops cleanly and is undoable for what was applied',
    () async {
      final rig = Rig();
      final before = fingerprint(await rig.all());
      final people = await rig.all();
      final edited = [for (final p in people) p.copy()..name = '${p.name} X'];
      final big = Planner.batch(people, edited);
      final token = CancelToken();
      var calls = 0;
      final r = await rig.executor.run(
        ChangeSet(big.intent, [
          ...big.changes,
          ...big.changes,
          ...big.changes,
          ...big.changes,
          ...big.changes,
        ]),
        cancel: token,
        onProgress: (_) {
          if (++calls == 1) token.cancel();
        },
      );
      expect(r.cancelled, isTrue);
      expect(r.ok, Executor.batchSize);
      expect(r.entry.state, EntryState.cancelled);
      expect(r.skipped, greaterThan(0));
      final u = await rig.undo(r);
      expect(u.failed, 0);
      expect(fingerprint(await rig.all()), before);
    },
  );

  test('undo restores an identical state for create', () async {
    final rig = Rig();
    final before = fingerprint(await rig.all());
    final r = await rig.executor.run(
      Planner.create(
        Person(
          name: 'New Person',
          phones: [const PhoneEntry('+1 202 555 0101')],
        ),
        account: google,
      ),
    );
    expect(r.ok, 1);
    expect(r.entry.records.single.phoneId, isNotNull);
    expect(rig.source.size, 7);
    await rig.undo(r);
    expect(fingerprint(await rig.all()), before);
  });

  test('undo restores an identical state for update', () async {
    final rig = Rig();
    final before = fingerprint(await rig.all());
    final a = await rig.named('Amelia Hart');
    final after = a.copy()
      ..name = 'Amelia J. Hart'
      ..phones = [const PhoneEntry('+44 1')]
      ..emails = []
      ..starred = false
      ..groups = ['Other']
      ..note = '';
    final r = await rig.executor.run(Planner.edit(a, after));
    expect((await rig.named('Amelia J. Hart')).groups, ['Other']);
    await rig.undo(r);
    expect(fingerprint(await rig.all()), before);
    expect(rig.journal.byId(r.entry.id)!.canUndo, isFalse);
  });

  test(
    'undo restores an identical state for delete, including account',
    () async {
      final rig = Rig();
      final before = fingerprint(await rig.all());
      final r = await rig.executor.run(Planner.delete(await rig.all()));
      expect(rig.source.size, 0);
      await rig.undo(r);
      expect(fingerprint(await rig.all()), before);
    },
  );

  test('undo restores an identical state for merge', () async {
    final rig = Rig();
    final before = fingerprint(await rig.all());
    final groups = Merger.findDuplicates(await rig.all());
    expect(groups.length, 1);
    final r = await rig.executor.run(Merger.planAll(groups));
    expect(r.ok, 1);
    expect(rig.source.size, 5);
    final merged = (await rig.all()).firstWhere(
      (p) => p.name.startsWith('Ali'),
    );
    expect(merged.phones.length, 1);
    expect(merged.emails, ['ali@x.com']);
    await rig.undo(r);
    expect(fingerprint(await rig.all()), before);
  });

  test('undo of an undo re-applies the change', () async {
    final rig = Rig();
    final r = await rig.executor.run(Planner.delete([await rig.named('王伟')]));
    final u = await rig.undo(r);
    expect(rig.source.size, 6);
    await rig.undo(u);
    expect(rig.source.size, 5);
  });

  test('journal persists, and prunes to 30 entries and 30 days', () async {
    var now = DateTime(2026, 1, 1);
    final store = MemoryJournalStore();
    final journal = Journal(store, clock: () => now);
    final source = FakeSource(seed: seed());
    final ex = Executor(source, journal);
    for (var i = 0; i < 35; i++) {
      final p = (await source.readAll()).first;
      await ex.run(Planner.star([p], !p.starred));
      now = now.add(const Duration(hours: 1));
    }
    expect(journal.entries.length, Journal.maxEntries);
    expect(store.data.length, Journal.maxEntries);
    expect(journal.storageBytes, greaterThan(0));
    final reloaded = Journal(store, clock: () => now);
    await reloaded.load();
    expect(reloaded.entries.length, Journal.maxEntries);
    expect(
      reloaded.entries.first.time.isAfter(reloaded.entries.last.time),
      isTrue,
    );
    now = now.add(const Duration(days: 31));
    await reloaded.prune();
    expect(reloaded.entries, isEmpty);
    expect(store.data, isEmpty);
  });

  test(
    'an interrupted run reloads as cancelled with its backup intact',
    () async {
      final store = MemoryJournalStore();
      final journal = Journal(store);
      final people = seed().map((p) => p.copy(phoneId: p.name)).toList();
      final e = journal.begin(Planner.delete(people));
      await journal.save(e);
      final reloaded = Journal(store);
      await reloaded.load();
      expect(reloaded.entries.single.state, EntryState.cancelled);
      expect(reloaded.entries.single.backupContacts, people.length);
    },
  );
}
