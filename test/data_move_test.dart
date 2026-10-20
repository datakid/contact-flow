import 'dart:convert';

import 'package:contact_flow/calls/ignore_book.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/services/data_move.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppState, TagBook, IgnoreBook)> world() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState();
  await s.init(openStore: false);
  final t = TagBook(MemoryTagStore());
  await t.load();
  final i = IgnoreBook(MemoryTagStore());
  await i.load();
  return (s, t, i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PhoneKey.useRegion(''));

  test('export then import into a fresh install restores everything', () async {
    final (s1, t1, i1) = await world();
    s1.replacePeople([
      Person(
        name: 'Ann',
        phones: [const PhoneEntry('+966501234567')],
        emails: ['ann@example.com'],
        groups: ['Family'],
        jobTitle: 'Engineer',
      ),
      Person(name: 'Bob', phones: [const PhoneEntry('+966559876543')]),
    ]);
    final work = await t1.create('Work');
    await t1.assign([work.id], ['+966501234567', '+966551111111']);
    await i1.add(['+966552222222']);
    final text = DataMove.export(people: s1.people, tags: t1, ignore: i1);

    final (s2, t2, i2) = await world();
    final r = await DataMove.import(text, state: s2, tags: t2, ignore: i2);
    expect(r.people, 2);
    expect(r.tags, 2);
    expect(r.ignored, 1);
    expect(s2.people.map((p) => p.name).toSet(), {'Ann', 'Bob'});
    final ann = s2.people.firstWhere((p) => p.name == 'Ann');
    expect(ann.jobTitle, 'Engineer');
    expect(ann.groups, ['Family']);
    expect(t2.tagsForNumber('+966501234567').single.name, 'Work');
    expect(t2.tagsForNumber('+966551111111').single.name, 'Work');
    expect(i2.keys.length, 1);
  });

  test('importing the same file twice adds nothing new', () async {
    final (s1, t1, i1) = await world();
    s1.replacePeople([
      Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
    ]);
    final work = await t1.create('Work');
    await t1.assign([work.id], ['+966501234567']);
    await i1.add(['+966552222222']);
    final text = DataMove.export(people: s1.people, tags: t1, ignore: i1);

    final (s2, t2, i2) = await world();
    await DataMove.import(text, state: s2, tags: t2, ignore: i2);
    final again = await DataMove.import(text, state: s2, tags: t2, ignore: i2);
    expect(again.people, 0);
    expect(again.tags, 0);
    expect(again.ignored, 0);
    expect(s2.people.length, 1);
  });

  test('importing merges with contacts that are already there', () async {
    final (s1, t1, i1) = await world();
    s1.replacePeople([
      Person(
        name: 'Ann',
        phones: [const PhoneEntry('+966501234567')],
        emails: ['ann@example.com'],
      ),
    ]);
    final text = DataMove.export(people: s1.people, tags: t1, ignore: i1);

    final (s2, t2, i2) = await world();
    s2.replacePeople([
      Person(name: 'Ann', phones: [const PhoneEntry('0501234567')]),
    ]);
    await DataMove.import(text, state: s2, tags: t2, ignore: i2);
    expect(s2.people.length, 1);
  });

  test('a file that is not a data export is refused', () async {
    final (s, t, i) = await world();
    for (final bad in ['not json', '[]', jsonEncode({'kind': 'other'})]) {
      await expectLater(
        DataMove.import(bad, state: s, tags: t, ignore: i),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  test('an export with no tags or ignored numbers still imports contacts', () async {
    final (s, t, i) = await world();
    final text = jsonEncode({
      'kind': 'move',
      'people': [
        Person(name: 'Cy', phones: [const PhoneEntry('+966553333333')]).toJson(),
      ],
    });
    final r = await DataMove.import(text, state: s, tags: t, ignore: i);
    expect(r.people, 1);
    expect(r.tags, 0);
    expect(r.ignored, 0);
  });
}
