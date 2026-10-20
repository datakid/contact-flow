import 'package:contact_flow/calls/call_filter.dart';
import 'package:contact_flow/calls/call_models.dart';
import 'package:contact_flow/calls/call_source.dart';
import 'package:contact_flow/calls/calls_controller.dart';
import 'package:contact_flow/calls/ignore_book.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:flutter_test/flutter_test.dart';

final clock = DateTime(2026, 10, 20, 12);

CallRecord call(String n, {int days = 1, CallType type = CallType.incoming}) =>
    CallRecord(
      number: n,
      dateMs: clock.subtract(Duration(days: days)).millisecondsSinceEpoch,
      type: type,
    );

class Harness {
  final List<Person> phone;
  final List<Person> saved = [];
  final FakeCallSource source;
  final IgnoreBook ignore = IgnoreBook(MemoryTagStore());
  final TagBook tags = TagBook(MemoryTagStore());
  late final CallsController c;
  int refreshes = 0;
  List<Person> Function()? onRefresh;

  Harness(List<CallRecord> calls, {List<Person>? phone, bool granted = true})
    : phone = phone ?? [],
      source = FakeCallSource(calls, granted: granted) {
    c = CallsController(
      source: source,
      contacts: () => this.phone,
      refreshContacts: () async {
        refreshes++;
        final more = onRefresh?.call();
        if (more != null) this.phone.addAll(more);
      },
      saveToPhone: (people) async {
        saved.addAll(people);
        this.phone.addAll(people);
      },
      ignore: ignore,
      tags: tags,
      now: () => clock,
    );
  }
}

void main() {
  setUp(() => PhoneKey.useRegion('SA'));
  tearDown(() => PhoneKey.useRegion(''));

  final calls = [
    call('+966501234567', days: 1),
    call('+966501234567', days: 2),
    call('+966559876543', days: 3, type: CallType.missed),
    call('+966551111111', days: 50),
  ];

  test('start loads when permission is already there', () async {
    final h = Harness(calls);
    await h.c.start();
    expect(h.c.phase, CallsPhase.ready);
    expect(h.c.all.length, 3);
    expect(h.c.shown.length, 3);
  });

  test('start asks for permission when it is missing', () async {
    final h = Harness(calls, granted: false);
    await h.c.start();
    expect(h.c.phase, CallsPhase.needPermission);
    await h.c.grant();
    expect(h.c.phase, CallsPhase.needPermission);
    h.source.granted = true;
    await h.c.grant();
    expect(h.c.phase, CallsPhase.ready);
  });

  test('a failing read ends in the error phase', () async {
    final bad = CallsController(
      source: _Failing(),
      contacts: () => [],
      refreshContacts: () async {},
      saveToPhone: (_) async {},
      ignore: IgnoreBook(MemoryTagStore()),
    );
    await bad.load();
    expect(bad.phase, CallsPhase.error);
    expect(bad.error, isNotNull);
  });

  test('saved contacts do not appear', () async {
    final h = Harness(
      calls,
      phone: [Person(name: 'Ann', phones: [const PhoneEntry('0501234567')])],
    );
    await h.c.start();
    expect(h.c.all.map((g) => g.number), isNot(contains('+966501234567')));
    expect(h.c.all.length, 2);
  });

  test('a filter narrows the shown list and keeps all', () async {
    final h = Harness(calls);
    await h.c.start();
    h.c.setFilter(const CallFilter(minCalls: 2));
    expect(h.c.shown.length, 1);
    expect(h.c.all.length, 3);
    h.c.setFilter(const CallFilter(lastDays: 30));
    expect(h.c.shown.length, 2);
  });

  test('select all shown, invert, exclude and the counter', () async {
    final h = Harness(calls);
    await h.c.start();
    h.c.setFilter(const CallFilter(lastDays: 30));
    h.c.includeAllShown();
    expect(h.c.selection.included.length, 2);
    h.c.exclude(h.c.shown.first);
    expect(h.c.selection.included.length, 1);
    expect(h.c.selection.excluded.length, 1);
    h.c.invertShown();
    expect(h.c.selection.included.length, 0);
  });

  test('ignoring removes the callers and undo brings them back', () async {
    final h = Harness(calls);
    await h.c.start();
    final target = h.c.all.first;
    final undo = await h.c.ignoreNumbers([target]);
    expect(h.c.all.length, 2);
    expect(h.ignore.has(target.key), isTrue);
    undo();
    await Future<void>.delayed(Duration.zero);
    expect(h.c.all.length, 3);
  });

  test('showing hidden numbers brings back short codes', () async {
    final h = Harness([...calls, call('1234')]);
    await h.c.start();
    expect(h.c.all.length, 3);
    h.c.setShowHidden(true);
    expect(h.c.all.length, 4);
  });

  test('drafts use the template, the tag and the running number', () async {
    final h = Harness(calls);
    await h.c.start();
    final t = await h.tags.create('Work');
    await h.tags.assign([t.id], ['+966501234567']);
    h.c.includeAllShown();
    final names = h.c.drafts('{tag} {last4}').map((p) => p.name).toList()
      ..sort();
    expect(names, ['1111', '6543', 'Work 4567']);
  });

  test('a blank template names a contact by its number', () async {
    final h = Harness(calls);
    await h.c.start();
    h.c.include(h.c.all.first);
    expect(h.c.drafts('').single.name, h.c.all.first.number);
  });

  test('saving creates the chosen contacts and clears them', () async {
    final h = Harness(calls);
    await h.c.start();
    h.c.includeAllShown();
    final r = await h.c.save('Caller {n}');
    expect(r.saved, 3);
    expect(r.alreadyThere, 0);
    expect(h.saved.map((p) => p.name).toSet(), {'Caller 1', 'Caller 2', 'Caller 3'});
    expect(h.c.all, isEmpty);
    expect(h.c.selection.included, isEmpty);
    expect(h.refreshes, 1);
  });

  test('numbers saved in the meantime are dropped right before saving', () async {
    final h = Harness(calls);
    await h.c.start();
    h.c.includeAllShown();
    h.onRefresh = () => [
      Person(name: 'Late', phones: [const PhoneEntry('+966559876543')]),
    ];
    final r = await h.c.save('Caller {n}');
    expect(r.saved, 2);
    expect(r.alreadyThere, 1);
    expect(h.saved.length, 2);
    expect(h.saved.map((p) => p.phones.first.number), isNot(contains('+966559876543')));
  });

  test('tag-only action tags the chosen numbers without saving', () async {
    final h = Harness(calls);
    await h.c.start();
    final t = await h.tags.create('Work');
    h.c.include(h.c.all.first);
    expect(await h.c.tagChosen([t.id]), 1);
    expect(h.saved, isEmpty);
    expect(h.c.all.length, 3);
  });

  test('a pattern filter can use tags', () async {
    final h = Harness(calls);
    await h.c.start();
    final t = await h.tags.create('Work');
    await h.tags.assign([t.id], ['+966559876543']);
    h.c.setFilter(const CallFilter(pattern: '#work'));
    expect(h.c.shown.map((g) => g.number), ['+966559876543']);
  });
}

class _Failing implements CallSource {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> request() async => true;

  @override
  Future<List<CallRecord>> readAll({void Function(int loaded)? onPage}) async =>
      throw StateError('boom');
}
