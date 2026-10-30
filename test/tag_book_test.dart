import 'dart:io';

import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_models.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TagBook> fresh([TagStore? store]) async {
  final b = TagBook(store ?? MemoryTagStore());
  await b.load();
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PhoneKey.useRegion(''));

  group('tags', () {
    test('create trims and reuses an existing name', () async {
      final b = await fresh();
      final a = await b.create('  Work ');
      final again = await b.create('work');
      expect(a.name, 'Work');
      expect(again.id, a.id);
      expect(b.tags.length, 1);
    });

    test('rename refuses a name another tag uses', () async {
      final b = await fresh();
      final a = await b.create('Work');
      final c = await b.create('Home');
      expect(await b.rename(c.id, 'work'), isFalse);
      expect(await b.rename(c.id, 'Family'), isTrue);
      expect(b.byId(c.id)!.name, 'Family');
      expect(b.byId(a.id)!.name, 'Work');
    });

    test('recolour changes only the colour', () async {
      final b = await fresh();
      final a = await b.create('Work');
      await b.recolour(a.id, 0xFF112233);
      expect(b.byId(a.id)!.colour, 0xFF112233);
      expect(b.byId(a.id)!.name, 'Work');
    });

    test('tags list is sorted by name', () async {
      final b = await fresh();
      await b.create('b');
      await b.create('A');
      await b.create('c');
      expect(b.tags.map((t) => t.name), ['A', 'b', 'c']);
    });
  });

  group('numbers', () {
    test('a tag can be put on a number that is not a contact', () async {
      final b = await fresh();
      final t = await b.create('Work');
      expect(await b.assign([t.id], ['+966 50 123 4567']), 1);
      expect(b.tagsForNumber('+966501234567').single.name, 'Work');
    });

    test('formats of the same number share tags', () async {
      PhoneKey.useRegion('SA');
      final b = await fresh();
      final t = await b.create('Work');
      await b.assign([t.id], ['+966 50 123 4567']);
      expect(b.tagIdsForNumber('0501234567'), {t.id});
      expect(b.tagIdsForNumber('00966501234567'), {t.id});
      expect(b.tagIdsForNumber('+971501234567'), isEmpty);
    });

    test('assigning twice adds nothing the second time', () async {
      final b = await fresh();
      final t = await b.create('Work');
      expect(await b.assign([t.id], ['+966501234567']), 1);
      expect(await b.assign([t.id], ['+966 50 123 4567']), 0);
      expect(b.count(t.id), 1);
    });

    test('unassign removes only that tag', () async {
      final b = await fresh();
      final w = await b.create('Work');
      final h = await b.create('Home');
      await b.assign([w.id, h.id], ['+966501234567']);
      expect(await b.unassign([w.id], ['+966501234567']), 1);
      expect(b.tagsForNumber('+966501234567').map((t) => t.name), ['Home']);
    });

    test('a number that is too short is ignored', () async {
      final b = await fresh();
      final t = await b.create('Work');
      expect(await b.assign([t.id], ['123']), 0);
    });

    test('a contact shows the union of its numbers tags', () async {
      final b = await fresh();
      final w = await b.create('Work');
      final h = await b.create('Home');
      await b.assign([w.id], ['+966501234567']);
      await b.assign([h.id], ['+966559876543']);
      final p = Person(
        name: 'Ann',
        phones: [
          const PhoneEntry('+966501234567'),
          const PhoneEntry('+966559876543'),
        ],
      );
      expect(b.tagsForPerson(p).map((t) => t.name), ['Home', 'Work']);
      expect(b.personHasTag(p, 'WORK'), isTrue);
      expect(b.personHasTag(p, 'Other'), isFalse);
    });
  });

  group('delete, merge and undo', () {
    test(
      'delete removes the tag and its numbers, and undo restores them',
      () async {
        final b = await fresh();
        final t = await b.create('Work');
        await b.assign([t.id], ['+966501234567', '+966559876543']);
        final undo = await b.delete(t.id);
        expect(b.tags, isEmpty);
        expect(b.tagsForNumber('+966501234567'), isEmpty);
        await b.undo(undo);
        expect(b.tags.single.name, 'Work');
        expect(b.count(t.id), 2);
        expect(b.tagsForNumber('+966501234567').single.id, t.id);
      },
    );

    test(
      'merge moves numbers without duplicating and undo reverses it',
      () async {
        final b = await fresh();
        final a = await b.create('A');
        final c = await b.create('B');
        await b.assign([a.id], ['+966501234567', '+966559876543']);
        await b.assign([c.id], ['+966501234567']);
        final undo = await b.merge(a.id, c.id);
        expect(b.byId(a.id), isNull);
        expect(b.count(c.id), 2);
        await b.undo(undo);
        expect(b.byId(a.id), isNotNull);
        expect(b.count(a.id), 2);
        expect(b.count(c.id), 1);
      },
    );

    test('merging a tag into itself does nothing', () async {
      final b = await fresh();
      final a = await b.create('A');
      await b.merge(a.id, a.id);
      expect(b.byId(a.id), isNotNull);
    });
  });

  group('keys and regions', () {
    test('a valid number is keyed by its E.164 form', () {
      PhoneKey.useRegion('SA');
      expect(TagKey.of('0501234567'), '+966501234567');
      expect(TagKey.of('+966 50 123 4567'), '+966501234567');
    });

    test(
      'a number that cannot be parsed is keyed by national number and region',
      () {
        expect(TagKey.of('0501234567'), 'u:501234567@');
        PhoneKey.useRegion('SA');
        expect(TagKey.of('12345678901234'), 'u:678901234@SA');
      },
    );

    test(
      'changing the region moves unparsed tags and reports how many',
      () async {
        final b = await fresh();
        final t = await b.create('Work');
        await b.assign([t.id], ['0501234567']);
        expect(b.numbersFor(t.id).single.key, startsWith('u:'));
        PhoneKey.useRegion('SA');
        expect(await b.rekeyUnparsed(), 1);
        expect(b.numbersFor(t.id).single.key, '+966501234567');
        expect(b.tagsForNumber('0501234567').single.id, t.id);
        expect(b.count(t.id), 1);
      },
    );

    test('rekeying twice moves nothing the second time', () async {
      final b = await fresh();
      final t = await b.create('Work');
      await b.assign([t.id], ['0501234567']);
      PhoneKey.useRegion('SA');
      await b.rekeyUnparsed();
      expect(await b.rekeyUnparsed(), 0);
    });

    test(
      'an unparsed tag that already has a parsed twin is merged, not lost',
      () async {
        final b = await fresh();
        final t = await b.create('Work');
        await b.assign([t.id], ['0501234567']);
        PhoneKey.useRegion('SA');
        await b.assign([t.id], ['+966501234567']);
        await b.rekeyUnparsed();
        expect(b.count(t.id), 1);
      },
    );
  });

  group('persistence', () {
    test('a new book loads what the old one saved', () async {
      final store = MemoryTagStore();
      final a = await fresh(store);
      final t = await a.create('Work');
      await a.assign([t.id], ['+966501234567']);
      final b = await fresh(store);
      expect(b.tags.single.name, 'Work');
      expect(b.tagsForNumber('+966501234567').single.id, t.id);
    });

    test('number tags whose tag is gone are dropped on load', () async {
      final store = MemoryTagStore();
      final a = await fresh(store);
      final t = await a.create('Work');
      await a.assign([t.id], ['+966501234567']);
      store.data.removeWhere((k, _) => k.startsWith('tag:'));
      final b = await fresh(store);
      expect(b.tagsForNumber('+966501234567'), isEmpty);
    });

    test('unreadable entries are skipped', () async {
      final store = MemoryTagStore()..data['tag:x'] = '{broken';
      final b = await fresh(store);
      expect(b.tags, isEmpty);
    });

    test('Hive store keeps entries and hides its schema marker', () async {
      final dir = await Directory.systemTemp.createTemp('tags_hive');
      Hive.init(dir.path);
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      final store = HiveTagStore();
      await store.putAll({'tag:a': '{"id":"a","name":"Work"}'});
      final all = await store.loadAll();
      expect(all.keys, ['tag:a']);
      await store.removeAll(['tag:a']);
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('backup', () {
    test(
      'export then import into an empty book restores tags and numbers',
      () async {
        final a = await fresh();
        final w = await a.create('Work');
        final h = await a.create('Home');
        await a.assign([w.id], ['+966501234567', '+966559876543']);
        await a.assign([h.id], ['+966501234567']);
        final json = a.exportJson();
        final b = await fresh();
        expect(await b.importJson(json), 3);
        expect(b.tags.map((t) => t.name), ['Home', 'Work']);
        expect(b.tagsForNumber('+966501234567').map((t) => t.name), [
          'Home',
          'Work',
        ]);
      },
    );

    test('importing the same backup again adds nothing', () async {
      final a = await fresh();
      final w = await a.create('Work');
      await a.assign([w.id], ['+966501234567']);
      final json = a.exportJson();
      expect(await a.importJson(json), 0);
      expect(a.tags.length, 1);
    });
  });

  group('search', () {
    test('a #tag query finds contacts through their numbers tags', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init(openStore: false);
      final book = await fresh();
      final t = await book.create('VIP');
      await book.assign([t.id], ['+966501234567']);
      s.tagMatcher = book.personHasTag;
      s.replacePeople([
        Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
        Person(name: 'Bob', phones: [const PhoneEntry('+966559876543')]),
      ]);
      s.setQuery('#vip');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(s.hits.map((h) => h.person.name), ['Ann']);
    });
  });
}
