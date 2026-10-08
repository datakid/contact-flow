import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/batch/batch_ops.dart';
import 'package:contact_flow/data/phone_source.dart';
import 'package:contact_flow/domain/change_set.dart';
import 'package:contact_flow/domain/matcher.dart';
import 'package:contact_flow/domain/merger.dart';
import 'package:contact_flow/domain/sync.dart';
import 'package:contact_flow/domain/templates.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/search/fuzzy.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_test/flutter_test.dart';

Person who(
  String name, {
  List<String> aliases = const [],
  List<String> nums = const [],
  String? id,
}) => Person(
  name: name,
  aliases: [...aliases],
  phones: [for (final n in nums) PhoneEntry(n)],
  phoneId: id,
);

void main() {
  group('Aliases model', () {
    test('parse splits on common separators', () {
      expect(Aliases.parse('Abu Ali, Ali; Lulu | 小李\nDoc'), [
        'Abu Ali',
        'Ali',
        'Lulu',
        '小李',
        'Doc',
      ]);
      expect(Aliases.parse('أبو علي، علي'), ['أبو علي', 'علي']);
      expect(Aliases.parse('   '), isEmpty);
    });

    test('clean dedupes, trims and drops the name itself', () {
      expect(
        Aliases.clean([
          ' Ali ',
          'ali',
          'Ali Hassan',
          '',
          'Doc',
        ], name: 'ali hassan'),
        ['Ali', 'Doc'],
      );
    });

    test('union keeps order of first sighting', () {
      expect(
        Aliases.union([
          ['B', 'A'],
          ['a', 'C'],
        ]),
        ['B', 'A', 'C'],
      );
    });

    test('json round-trip keeps aliases and omits empty lists', () {
      final p = who('Sara Lee', aliases: ['Sasa', 'S.L.']);
      final back = Person.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.aliases, ['Sasa', 'S.L.']);
      expect(who('Bob').toJson().containsKey('aliases'), isFalse);
      expect(Person.fromJson(who('Bob').toJson()).aliases, isEmpty);
    });

    test('copy is independent', () {
      final p = who('A', aliases: ['x']);
      final c = p.copy()..aliases.add('y');
      expect(p.aliases, ['x']);
      expect(c.aliases, ['x', 'y']);
    });
  });

  group('Import and export', () {
    final people = [
      who(
        'Ahmed Saleh',
        aliases: ['Abu Omar', 'Hamoudi'],
        nums: ['+971 50 111 2222'],
      ),
      who('Plain Person', nums: ['+1 415 555 0100']),
    ];

    for (final f in [Format.vcf, Format.csv, Format.xlsx, Format.json]) {
      test('${f.name} keeps aliases', () {
        final bytes = Codec.encode(people, f, const ExportOptions());
        final r = Codec.decode('x.${f.exportExt}', bytes);
        final a = r.people.firstWhere((p) => p.name == 'Ahmed Saleh');
        expect(a.aliases, ['Abu Omar', 'Hamoudi']);
        final b = r.people.firstWhere((p) => p.name == 'Plain Person');
        expect(b.aliases, isEmpty);
      });
    }

    test('aliases can be left out of exports', () {
      const o = ExportOptions(includeAliases: false);
      final rows = Codec.table(people, o);
      expect(rows.first.any((h) => h.toLowerCase().contains('alias')), isFalse);
      final r = Codec.decode('x.csv', Codec.encode(people, Format.csv, o));
      expect(r.people.every((p) => p.aliases.isEmpty), isTrue);
    });

    test('no alias column when nobody has one', () {
      final rows = Codec.table([people[1]], const ExportOptions());
      expect(rows.first.any((h) => h.toLowerCase().contains('alias')), isFalse);
    });

    test('vCard NICKNAME from other apps', () {
      const v =
          'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Lina Haddad\r\nNICKNAME:Lulu,Lino\r\nTEL:+33 6 12 34 56 78\r\nEND:VCARD\r\n'
          'BEGIN:VCARD\r\nVERSION:2.1\r\nX-ANDROID-NICKNAME:Bobby\r\nTEL:+44 20 7946 0001\r\nEND:VCARD\r\n';
      final r = Codec.decode('a.vcf', Uint8List.fromList(utf8.encode(v)));
      expect(r.people.first.aliases, ['Lulu', 'Lino']);
      expect(r.people.last.name, 'Bobby');
    });

    test('CSV headers in several languages', () {
      for (final h in [
        'Nickname',
        'AKA',
        'الاسم المستعار',
        '别名',
        'Apodo',
        'Surnom',
      ]) {
        final csv = 'Name,Phone,$h\nOmar Ali,+971501112222,"Abu Ali, Omari"\n';
        final r = Codec.decode('x.csv', Uint8List.fromList(utf8.encode(csv)));
        expect(r.people.single.aliases, ['Abu Ali', 'Omari'], reason: h);
      }
    });
  });

  group('Search', () {
    final people = [
      who('Ahmed Saleh', aliases: ['Abu Omar']),
      who('Omar Farouk'),
      who('Zed', aliases: ['Zorro', 'Zee']),
    ];
    final idx = FuzzyIndex()..build(people);

    test('finds a contact by alias and says which', () {
      final hits = idx.search('zorro');
      expect(hits.first.person.name, 'Zed');
      expect(hits.first.reason, 'alias');
      expect(hits.first.alias, 'Zorro');
    });

    test('each person appears once and real names rank first', () {
      final hits = idx.search('omar');
      expect(hits.where((h) => h.person.name == 'Ahmed Saleh').length, 1);
      expect(hits.first.person.name, 'Omar Farouk');
    });

    test('size ignores alias entries', () {
      expect(idx.size, 3);
    });
  });

  group('Domain', () {
    test('merging keeps the other names as aliases', () {
      final out = Merger.combine(who('Ahmed Saleh', aliases: ['Abu Omar']), [
        who('Ahmed', aliases: ['Hamoudi']),
        who('ahmed saleh'),
      ]);
      expect(out.name, 'Ahmed Saleh');
      expect(out.aliases, ['Abu Omar', 'Hamoudi', 'Ahmed']);
    });

    test('sync policies', () {
      final target = who('Sara', aliases: ['Sasa'], id: '1');
      final row = who('Sara', aliases: ['Soso']);
      expect(
        SyncPlanner.applyPolicy(target, row, FieldPolicy.overwrite).aliases,
        ['Soso'],
      );
      expect(
        SyncPlanner.applyPolicy(target, row, FieldPolicy.fillEmpty).aliases,
        ['Sasa'],
      );
      expect(
        SyncPlanner.applyPolicy(target, row, FieldPolicy.addNumbers).aliases,
        ['Sasa', 'Soso'],
      );
      expect(
        SyncPlanner.applyPolicy(
          target,
          who('Sara'),
          FieldPolicy.overwrite,
        ).aliases,
        ['Sasa'],
      );
      expect(
        SyncPlanner.applyPolicy(
          who('Sara'),
          row,
          FieldPolicy.fillEmpty,
        ).aliases,
        ['Soso'],
      );
    });

    test('diff shows alias changes', () {
      final f = diffFields(
        who('A', aliases: ['x']),
        who('A', aliases: ['x', 'y']),
      );
      expect(f.single.field, ContactField.aliases);
    });

    test('matcher falls back to aliases', () {
      final phone = [
        who('Ahmed Saleh', aliases: ['Abu Omar'], id: '1'),
      ];
      final r = ContactMatcher(phone).match([who('Abu Omar')]);
      expect(r.matched.single.target.phoneId, '1');
    });

    test('template {alias}', () {
      const t = MessageTemplate('Hi {alias}!');
      expect(
        t.render(who('Ahmed Saleh', aliases: ['Abu Omar'])),
        'Hi Abu Omar!',
      );
      expect(t.render(who('Ahmed Saleh')), 'Hi Ahmed!');
      expect(t.usesTokens, isTrue);
    });
  });

  group('Batch ops', () {
    test('add alias is idempotent and skips the name', () {
      final a = who('Lina');
      final once = BatchOp.run(const AddAlias('Lulu'), [a]).single.$2;
      expect(once.aliases, ['Lulu']);
      expect(BatchOp.run(const AddAlias('lulu'), [once]), isEmpty);
      expect(BatchOp.run(const AddAlias('Lina'), [a]), isEmpty);
    });

    test('keep name, promote, clear', () {
      final kept = BatchOp.run(const KeepNameAsAlias(), [
        who('Lina H'),
      ]).single.$2;
      expect(kept.aliases, ['Lina H']);
      final pro = BatchOp.run(const PromoteAlias(), [
        who('Lina', aliases: ['Lulu', 'Lino']),
      ]).single.$2;
      expect(pro.name, 'Lulu');
      expect(pro.aliases, ['Lino', 'Lina']);
      final cleared = BatchOp.run(const ClearAliases(), [pro]).single.$2;
      expect(cleared.aliases, isEmpty);
      expect(BatchOp.run(const ClearAliases(), [who('X')]), isEmpty);
    });
  });

  group('Phone write-back', () {
    fc.Contact base() => fc.Contact(
      id: '7',
      displayName: 'Ahmed Saleh',
      name: fc.Name(
        first: 'Ahmed',
        last: 'Saleh',
        prefix: 'Dr.',
        nickname: 'Abu Omar',
      ),
      phones: [const fc.Phone(number: '+971 50 111 2222')],
    );

    test('reads nickname rows as aliases', () {
      expect(PhoneSource.aliasesOf(base(), 'Ahmed Saleh'), ['Abu Omar']);
    });

    test('untouched name keeps structured parts', () {
      final out = PhoneSource.apply(
        base(),
        who('Ahmed Saleh', aliases: ['Abu Omar'], nums: ['+971 50 111 2222']),
      );
      expect(out.name?.prefix, 'Dr.');
      expect(out.name?.nickname, 'Abu Omar');
    });

    test('new aliases write the nickname and keep the name parts', () {
      final out = PhoneSource.apply(
        base(),
        who(
          'Ahmed Saleh',
          aliases: ['Abu Omar', 'Hamoudi'],
          nums: ['+971 50 111 2222'],
        ),
      );
      expect(out.name?.prefix, 'Dr.');
      expect(out.name?.first, 'Ahmed');
      expect(out.name?.nickname, 'Abu Omar, Hamoudi');
    });

    test('clearing aliases clears the nickname', () {
      final out = PhoneSource.apply(
        base(),
        who('Ahmed Saleh', nums: ['+971 50 111 2222']),
      );
      expect(out.name?.nickname, anyOf(isNull, isEmpty));
      expect(out.phones.single.number, '+971 50 111 2222');
    });
  });
}
