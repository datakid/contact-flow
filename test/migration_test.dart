import 'dart:convert';
import 'dart:io';

import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/services/library_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const legacyRecords = [
  {
    'id': 'm1a2b3',
    'name': 'Amelia Hart',
    'phones': [
      {'number': '+44 7700 900461', 'label': 'mobile'},
      {'number': '+44 20 7946 0958', 'label': 'work'},
    ],
    'emails': ['amelia@hart.studio'],
    'org': 'Hart Studio',
    'note': 'met in London',
    'source': 'contacts.vcf',
    'added': 1759000000000,
  },
  {
    'id': 'm1a2b4',
    'name': 'محمد عبد الله',
    'phones': [
      {'number': '+966 50 123 4567', 'label': 'mobile'},
    ],
    'emails': [],
    'org': 'أرامكو',
    'note': '',
    'source': 'device',
    'added': 1759000000001,
  },
  {
    'id': 'm1a2b5',
    'name': '王伟',
    'phones': [
      {'number': '+86 138 0013 8000'},
    ],
    'org': '',
    'source': 'sheet.xlsx',
    'added': 1759000000002,
  },
];

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cf_migrate');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'a library_v1 box written by 2.0.1 loads intact and is upgraded',
    () async {
      final legacy = await Hive.openBox<String>(LibraryStore.boxName);
      for (final r in legacyRecords) {
        await legacy.put(r['id'] as String, jsonEncode(r));
      }
      await legacy.put('corrupt', '{not json');
      await legacy.close();

      final store = LibraryStore();
      await store.openIn();
      final people = store.load();
      expect(people.length, 3);
      final byId = {for (final p in people) p.id: p};
      final a = byId['m1a2b3']!;
      expect(a.name, 'Amelia Hart');
      expect(a.phones.map((e) => '${e.label}:${e.number}'), [
        'mobile:+44 7700 900461',
        'work:+44 20 7946 0958',
      ]);
      expect(a.emails, ['amelia@hart.studio']);
      expect(a.org, 'Hart Studio');
      expect(a.note, 'met in London');
      expect(a.source, 'contacts.vcf');
      expect(a.added.millisecondsSinceEpoch, 1759000000000);
      expect(a.phoneId, isNull);
      expect(a.starred, isFalse);
      expect(a.groups, isEmpty);
      expect(a.jobTitle, '');
      expect(byId['m1a2b4']!.name, 'محمد عبد الله');
      expect(byId['m1a2b5']!.phones.single.label, 'mobile');

      final raw =
          jsonDecode(
                (await Hive.openBox<String>(
                  LibraryStore.boxName,
                )).get('m1a2b3')!,
              )
              as Map;
      expect(raw['v'], Person.schemaVersion);
      final meta = await Hive.openBox<int>(LibraryStore.metaBox);
      expect(meta.get(LibraryStore.schemaKey), Person.schemaVersion);
      expect(await store.migrate(), 0);
    },
  );

  test('new fields survive a save and reload', () async {
    final store = LibraryStore();
    await store.openIn();
    await store.putAll([
      Person(
        id: 'x',
        name: 'Ali',
        phoneId: '42',
        starred: true,
        groups: ['Family'],
        jobTitle: 'CTO',
        account: const AccountRef('me@gmail.com', 'com.google'),
      ),
    ]);
    final p = store.load().single;
    expect(p.phoneId, '42');
    expect(p.starred, isTrue);
    expect(p.groups, ['Family']);
    expect(p.jobTitle, 'CTO');
    expect(p.account?.isGoogle, isTrue);
  });
}
