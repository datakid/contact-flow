import 'package:contact_flow/domain/change_set.dart';
import 'package:contact_flow/domain/international.dart';
import 'package:contact_flow/domain/matcher.dart';
import 'package:contact_flow/domain/merger.dart';
import 'package:contact_flow/domain/names.dart';
import 'package:contact_flow/domain/planner.dart';
import 'package:contact_flow/domain/sync.dart';
import 'package:contact_flow/domain/templates.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

Person phoneContact(
  String id,
  String name, [
  List<String> numbers = const [],
  String org = '',
]) => Person(
  name: name,
  phoneId: id,
  phones: [for (final n in numbers) PhoneEntry(n)],
  org: org,
);

Person row(String name, [List<String> numbers = const [], String? id]) =>
    Person(
      name: name,
      phones: [for (final n in numbers) PhoneEntry(n)],
      phoneId: id,
    );

void main() {
  group('Planner', () {
    final a = phoneContact('1', 'Amelia Hart', ['+44 7700 900461']);
    final b = phoneContact('2', 'Bob Stone', ['050 123 4567']);

    test('create strips any phone id and keeps the account', () {
      final set = Planner.create(
        Person(name: 'New', phoneId: 'x'),
        account: const AccountRef('me@example.com', 'com.google'),
      );
      final c = set.changes.single as CreateChange;
      expect(c.after.phoneId, isNull);
      expect(c.account?.isGoogle, isTrue);
      expect(set.intent, ChangeIntent.create);
    });

    test('edit with no difference produces nothing', () {
      expect(Planner.edit(a, a.copy()).isEmpty, isTrue);
    });

    test('edit records field-level before and after', () {
      final after = a.copy()..org = 'Hart Studio';
      final u = Planner.edit(a, after).changes.single as UpdateChange;
      expect(u.fields.single.field, ContactField.company);
      expect(u.fields.single.before, '');
      expect(u.fields.single.after, 'Hart Studio');
    });

    test('delete, star and group', () {
      expect(Planner.delete([a, b]).count(ChangeKind.delete), 2);
      final starred = Planner.star([a, b], true);
      expect(starred.length, 2);
      expect(
        Planner.star([starred.changes.first.subject], true).isEmpty,
        isTrue,
      );
      final grouped = Planner.group([a], 'Family', true);
      expect((grouped.changes.single as UpdateChange).after.groups, ['Family']);
      expect(Planner.group([a], '  ', true).isEmpty, isTrue);
      final ungrouped = Planner.group(
        [
          a.copy()..groups = ['Family'],
        ],
        'Family',
        false,
      );
      expect((ungrouped.changes.single as UpdateChange).after.groups, isEmpty);
    });

    test('batch keeps only changed rows', () {
      final set = Planner.batch(
        [a, b],
        [a.copy(), b.copy()..name = 'Robert Stone'],
      );
      expect(set.length, 1);
      expect(set.changes.single.subject.name, 'Robert Stone');
      expect(set.intent, ChangeIntent.batch);
    });

    test('synced deletes are flagged', () {
      final g = a.copy()
        ..account = const AccountRef('me@gmail.com', 'com.google');
      final local = b.copy()..account = AccountRef.device;
      expect(Planner.delete([local]).deletesFromSyncedAccount, isFalse);
      expect(Planner.delete([g]).deletesFromSyncedAccount, isTrue);
    });
  });

  group('Matcher', () {
    final phone = [
      phoneContact('1', 'Amelia Hart', ['+971 50 123 4567']),
      phoneContact('2', 'Bob Stone', ['+44 20 7946 0001']),
      phoneContact('3', 'Reception Desk', ['+971 4 555 0000']),
      phoneContact('4', 'Carla Office', ['+971 4 555 0000']),
      phoneContact('5', 'Dana Lee'),
      phoneContact('6', 'Sam Twin'),
      phoneContact('7', 'Sam Twin'),
    ];
    final m = ContactMatcher(phone);

    test('contact_id wins over everything', () {
      final r = m.match([
        row('Totally Different', ['+1 999 999 9999'], '2'),
      ]);
      expect(r.matched.single.target.phoneId, '2');
      expect(r.matched.single.reason, MatchReason.contactId);
    });

    test('number variants +971, 00971 and 05x are equal', () {
      for (final n in ['+971501234567', '00971 50 123 4567', '050 123 4567']) {
        final r = m.match([
          row('', [n]),
        ]);
        expect(r.matched.single.target.phoneId, '1', reason: n);
        expect(r.matched.single.reason, MatchReason.number);
      }
    });

    test('exact normalized name when no number matches', () {
      final r = m.match([row('dana  LEE')]);
      expect(r.matched.single.target.phoneId, '5');
      expect(r.matched.single.reason, MatchReason.name);
    });

    test('two people sharing an office number are never merged', () {
      final r = m.match([
        row('Someone Else', ['00971 4 555 0000']),
      ]);
      expect(r.matched, isEmpty);
      expect(r.conflicts.single.reason, ConflictReason.sharedNumber);
      expect(r.conflicts.single.candidates.map((p) => p.phoneId).toSet(), {
        '3',
        '4',
      });
    });

    test('local landline without trunk digits never matches by guess', () {
      final r = m.match([
        row('Someone Else', ['04 555 0000']),
      ]);
      expect(r.matched, isEmpty);
    });

    test('a shared number with a matching name resolves to that person', () {
      final r = m.match([
        row('Carla Office', ['+971 4 555 0000']),
      ]);
      expect(r.matched.single.target.phoneId, '4');
    });

    test('ambiguous names become conflicts, not guesses', () {
      final r = m.match([row('Sam Twin')]);
      expect(r.matched, isEmpty);
      expect(r.conflicts.single.reason, ConflictReason.sameName);
    });

    test('two rows claiming one contact both become conflicts', () {
      final r = m.match([
        row('Bob Stone'),
        row('', ['+44 20 7946 0001']),
      ]);
      expect(r.matched, isEmpty);
      expect(r.conflicts.length, 2);
      expect(
        r.conflicts.every((c) => c.reason == ConflictReason.claimedTwice),
        isTrue,
      );
    });

    test('a row shared by two file rows does not match by number', () {
      final r = m.match([
        row('X', ['+44 20 7946 0001']),
        row('Y', ['+44 20 7946 0001']),
      ]);
      expect(r.matched, isEmpty);
    });

    test('unmatched rows and phone-only contacts are reported', () {
      final r = m.match([
        row('Nobody', ['+1 202 555 0199']),
      ]);
      expect(r.unmatched.single.name, 'Nobody');
      expect(r.onlyOnPhone.length, phone.length);
    });
  });

  group('Field policies', () {
    final target = Person(
      name: 'Amelia Hart',
      phoneId: '1',
      phones: [const PhoneEntry('+44 7700 900461')],
      org: '',
      note: 'met in London',
    );
    final incoming = Person(
      name: 'Amelia J. Hart',
      phones: [
        const PhoneEntry('+44 7700 900461'),
        const PhoneEntry('+44 20 1111 2222', 'work'),
      ],
      emails: ['amelia@hart.studio'],
      org: 'Hart Studio',
      note: 'designer',
    );

    test('fill empty keeps existing values', () {
      final r = SyncPlanner.applyPolicy(
        target,
        incoming,
        FieldPolicy.fillEmpty,
      );
      expect(r.name, 'Amelia Hart');
      expect(r.org, 'Hart Studio');
      expect(r.phones.length, 1);
      expect(r.emails, ['amelia@hart.studio']);
      expect(r.note, 'met in London');
      expect(r.phoneId, '1');
    });

    test('overwrite replaces with non-empty file values', () {
      final r = SyncPlanner.applyPolicy(
        target,
        incoming,
        FieldPolicy.overwrite,
      );
      expect(r.name, 'Amelia J. Hart');
      expect(r.phones.length, 2);
      expect(r.note, 'designer');
      final blank = SyncPlanner.applyPolicy(
        target,
        Person(name: ''),
        FieldPolicy.overwrite,
      );
      expect(sameContent(blank, target), isTrue);
    });

    test('add numbers unions without repeats', () {
      final r = SyncPlanner.applyPolicy(
        target,
        incoming,
        FieldPolicy.addNumbers,
      );
      expect(r.name, 'Amelia Hart');
      expect(r.phones.map((e) => e.number), [
        '+44 7700 900461',
        '+44 20 1111 2222',
      ]);
      expect(r.note, 'met in London\ndesigner');
    });
  });

  group('Sync planner', () {
    final phone = [
      phoneContact('1', 'Amelia Hart', ['+971 50 123 4567']),
      phoneContact('2', 'Bob Stone', ['+44 20 7946 0001'], 'Stone & Co'),
      phoneContact('3', 'Old Friend', ['+1 202 555 0100']),
      phoneContact('4', 'Sam Twin'),
      phoneContact('5', 'Sam Twin'),
    ];

    test('groups new, update, unchanged, conflicts and phone-only', () {
      final plan = SyncPlanner.plan(phone, [
        row('Amelia Hart', ['050 123 4567'])..org = 'Hart Studio',
        row('Bob Stone', ['+44 20 7946 0001']),
        row('Brand New', ['+33 6 12 34 56 78']),
        row('Sam Twin', ['+49 151 0000 0000']),
      ], FieldPolicy.fillEmpty);
      expect(plan.updates.single.before.phoneId, '1');
      expect(plan.updates.single.fields.single.field, ContactField.company);
      expect(plan.unchanged.single.target.phoneId, '2');
      expect(plan.fresh.single.name, 'Brand New');
      expect(plan.conflicts.single.candidates.length, 2);
      expect(plan.onlyOnPhone.single.phoneId, '3');
    });

    test('choices: skip, resolve conflict, opt-in deletion', () {
      final plan = SyncPlanner.plan(phone, [
        row('Brand New', ['+33 6 12 34 56 78']),
        row('Sam Twin', ['+49 151 0000 0000']),
      ], FieldPolicy.addNumbers);
      final none = SyncPlanner.toChangeSet(plan, const SyncChoices());
      expect(none.count(ChangeKind.create), 1);
      expect(none.count(ChangeKind.delete), 0);
      final target = plan.conflicts.single.candidates.last.id;
      final set = SyncPlanner.toChangeSet(
        plan,
        SyncChoices(
          skipFresh: {0},
          conflictTargets: {0: target},
          deleteOnlyOnPhone: {phone[2].id},
        ),
      );
      expect(set.count(ChangeKind.create), 0);
      expect(set.count(ChangeKind.update), 1);
      expect((set.changes.first as UpdateChange).before.phoneId, '5');
      expect(set.count(ChangeKind.delete), 1);
    });
  });

  group('Merger', () {
    test('union without repeats across number formats and email case', () {
      final a = Person(
        name: 'Ali',
        phones: [const PhoneEntry('+971 50 123 4567')],
        emails: ['ALI@x.com'],
        note: 'friend',
      );
      final b = Person(
        name: '',
        phones: [
          const PhoneEntry('050 123 4567'),
          const PhoneEntry('+971 4 222 3333', 'work'),
        ],
        emails: ['ali@x.com', 'ali@work.com'],
        note: 'Friend\ncolleague',
        org: 'ACME',
        starred: true,
        groups: ['Work'],
      );
      final c = Merger.combine(a, [b]);
      expect(c.name, 'Ali');
      expect(c.phones.length, 2);
      expect(c.emails, ['ALI@x.com', 'ali@work.com']);
      expect(c.note, 'friend\ncolleague');
      expect(c.org, 'ACME');
      expect(c.starred, isTrue);
      expect(c.groups, ['Work']);
    });

    test('finds groups by shared number or identical name with reasons', () {
      final people = [
        phoneContact('1', 'Ali Hassan', ['+971 50 123 4567']),
        phoneContact('2', 'Ali H', ['0501234567']),
        phoneContact('3', 'Mona', ['+20 100 000 0000']),
        phoneContact('4', 'mona', ['+20 111 111 1111']),
        phoneContact('5', 'Solo', ['+1 415 555 0101']),
      ];
      final groups = Merger.findDuplicates(people);
      expect(groups.length, 2);
      final byNumber = groups.firstWhere(
        (g) => g.people.any((p) => p.phoneId == '1'),
      );
      expect(byNumber.reasons, {DuplicateReason.sharedNumber});
      expect(byNumber.evidence, isNotEmpty);
      final byName = groups.firstWhere(
        (g) => g.people.any((p) => p.phoneId == '3'),
      );
      expect(byName.reasons, {DuplicateReason.sameName});
    });

    test('merge all suggests the richest contact to keep', () {
      final thin = phoneContact('1', '', ['+971 50 123 4567']);
      final rich = phoneContact('2', 'Ali Hassan', ['0501234567'], 'ACME');
      final set = Merger.planAll(Merger.findDuplicates([thin, rich]));
      final m = set.changes.single as MergeChange;
      expect(m.keepBefore.phoneId, '2');
      expect(m.removed.single.phoneId, '1');
      expect(set.affectedContacts, 2);
    });
  });

  group('Templates and names', () {
    final p = Person(name: 'Amelia Hart', org: 'Hart Studio');

    test('renders tokens', () {
      expect(
        const MessageTemplate('Hi {first} {last} from {company}!').render(p),
        'Hi Amelia Hart from Hart Studio!',
      );
      expect(
        const MessageTemplate('Dear {name},').render(p),
        'Dear Amelia Hart,',
      );
    });

    test('missing values do not leave gaps', () {
      final solo = Person(name: 'Cher');
      expect(
        const MessageTemplate('Hi {first} {last}, see you').render(solo),
        'Hi Cher, see you',
      );
      expect(const MessageTemplate('{company} rocks').render(solo), 'rocks');
    });

    test('Arabic and Chinese names', () {
      expect(
        const MessageTemplate(
          'مرحبا {first}',
        ).render(Person(name: 'محمد عبد الله')),
        'مرحبا محمد عبد',
      );
      expect(NameParts.of('王伟').first, '伟');
      expect(NameParts.of('王伟').last, '王');
      expect(NameParts.normalized('  José   ÁLVAREZ '), 'jose alvarez');
    });
  });

  group('International numbers', () {
    test('keeps numbers that already have a prefix', () {
      expect(InternationalNumber.of('+44 7700 900461').e164, '+447700900461');
      expect(InternationalNumber.of('00971 50 123 4567').e164, '+971501234567');
      expect(InternationalNumber.of('٠٠٩٧١٥٠١٢٣٤٥٦٧').e164, '+971501234567');
    });

    test('asks for a country when none is known', () {
      expect(
        InternationalNumber.of('050 123 4567').status,
        InternationalStatus.needsCountry,
      );
    });

    test('applies the default country and drops the trunk zero', () {
      final n = InternationalNumber.of('050 123 4567', country: '+971');
      expect(n.e164, '+971501234567');
      expect(n.digits, '971501234567');
      expect(
        InternationalNumber.of('971501234567', country: '971').e164,
        '+971501234567',
      );
      expect(
        InternationalNumber.of('(415) 555-0101', country: '1').e164,
        '+14155550101',
      );
    });

    test('rejects garbage', () {
      expect(InternationalNumber.of('12').status, InternationalStatus.invalid);
      expect(
        InternationalNumber.of('+0 123 456 789').status,
        InternationalStatus.invalid,
      );
    });
  });
}
