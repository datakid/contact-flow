import 'package:contact_flow/main.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/group_import.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/group_tags_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

final people = [
  Person(
    name: 'Ann',
    phones: [
      const PhoneEntry('+966511100001'),
      const PhoneEntry('+966511100002'),
    ],
    groups: ['Family', 'Gym'],
  ),
  Person(
    name: 'Bob',
    phones: [const PhoneEntry('+966511100003')],
    groups: ['Family'],
  ),
  Person(name: 'Cy', phones: [const PhoneEntry('+966511100004')]),
  Person(
    name: 'Di',
    phones: [const PhoneEntry('+966511100005')],
    groups: ['  '],
  ),
];

void main() {
  group('plan and apply', () {
    test('groups are listed with contact and number counts, sorted', () {
      final plans = GroupTagImport.plan(people);
      expect(plans.map((g) => g.name), ['Family', 'Gym']);
      expect(plans.first.contacts, 2);
      expect(plans.first.numbers, 3);
      expect(plans.last.contacts, 1);
    });

    test('blank group names and contacts without groups are ignored', () {
      expect(GroupTagImport.plan([people[2], people[3]]), isEmpty);
    });

    test(
      'applying creates a tag and tags every number of the members',
      () async {
        final book = TagBook(MemoryTagStore());
        await book.load();
        final plans = GroupTagImport.plan(people);
        final added = await GroupTagImport.apply(book, [plans.first]);
        expect(added, 3);
        expect(book.tagsForNumber('+966511100001').single.name, 'Family');
        expect(book.tagsForNumber('+966511100003').single.name, 'Family');
        expect(book.tagsForNumber('+966511100004'), isEmpty);
        expect(book.byName('Gym'), isNull);
      },
    );

    test('applying twice adds nothing the second time', () async {
      final book = TagBook(MemoryTagStore());
      await book.load();
      final plans = GroupTagImport.plan(people);
      await GroupTagImport.apply(book, plans);
      expect(await GroupTagImport.apply(book, plans), 0);
    });

    test('an existing tag with the same name is reused', () async {
      final book = TagBook(MemoryTagStore());
      await book.load();
      final existing = await book.create('family');
      await GroupTagImport.apply(book, GroupTagImport.plan(people));
      expect(
        book.tags.where((t) => t.name.toLowerCase() == 'family').length,
        1,
      );
      expect(book.count(existing.id), 3);
    });
  });

  group('sheet', () {
    testWidgets('pick a group and apply', (t) async {
      SharedPreferences.setMockInitialValues({'lang': 'en'});
      final app = AppState();
      await t.runAsync(() => app.init(openStore: false));
      final rig = (await t.runAsync(() => makeRig(app: app)))!;
      final book = TagBook(MemoryTagStore());
      await t.runAsync(book.load);
      await t.pumpWidget(
        AppProviders(
          state: rig.app,
          book: rig.book,
          queue: rig.queue,
          launcher: rig.launcher,
          tags: book,
          child: ContactFlowApp(
            home: Scaffold(
              body: GroupTagsSheet(
                plans: GroupTagImport.plan(people),
                tags: book,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('2 contacts · 3 numbers'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('group-tag-Family')));
      await t.pumpAndSettle();
      expect(find.text('Import 1 groups as tags'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('group-tags-apply')));
      await t.pumpAndSettle();
      expect(book.byName('Family'), isNotNull);
    });

    testWidgets('an empty list says so', (t) async {
      SharedPreferences.setMockInitialValues({'lang': 'en'});
      final app = AppState();
      await t.runAsync(() => app.init(openStore: false));
      final rig = (await t.runAsync(() => makeRig(app: app)))!;
      final book = TagBook(MemoryTagStore());
      await t.runAsync(book.load);
      await t.pumpWidget(
        rig.wrap(
          ContactFlowApp(
            home: Scaffold(
              body: GroupTagsSheet(plans: const [], tags: book),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('group-tags-none')), findsOneWidget);
    });
  });
}
