import 'dart:convert';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = [
    Person(
      name: 'Ann Lee',
      phones: [const PhoneEntry('+966551234567')],
      org: 'Acme',
      jobTitle: 'Engineer',
      groups: ['Work', 'VIP'],
    ),
    Person(name: 'Bob Ray', phones: [const PhoneEntry('+966559876543')]),
  ];

  test('CSV leaves job title and groups out by default', () {
    final rows = Codec.table(people, const ExportOptions(), format: Format.csv);
    expect(rows.first, isNot(contains('Job Title')));
    expect(rows.first, isNot(contains('Groups')));
  });

  test('CSV can include them and they come back on import', () {
    const o = ExportOptions(includeTitle: true, includeGroups: true);
    final rows = Codec.table(people, o, format: Format.csv);
    expect(rows.first, containsAll(['Job Title', 'Groups']));
    final back = Codec.decode('x.csv', Codec.encode(people, Format.csv, o));
    final ann = back.people.firstWhere((p) => p.name == 'Ann Lee');
    expect(ann.jobTitle, 'Engineer');
    expect(ann.groups, ['Work', 'VIP']);
  });

  test('XLSX includes them by default', () {
    final rows = Codec.table(people, const ExportOptions());
    expect(rows.first, containsAll(['Job Title', 'Groups']));
    final back = Codec.decode(
      'x.xlsx',
      Codec.encode(people, Format.xlsx, const ExportOptions()),
    );
    final ann = back.people.firstWhere((p) => p.name == 'Ann Lee');
    expect(ann.jobTitle, 'Engineer');
    expect(ann.groups, ['Work', 'VIP']);
  });

  test('no extra columns when nobody has the data', () {
    final rows = Codec.table([people[1]], const ExportOptions());
    expect(rows.first, isNot(contains('Job Title')));
    expect(rows.first, isNot(contains('Groups')));
  });

  test('contact_id stays the last column', () {
    final withId = [people[0]..phoneId = '7'];
    final rows = Codec.table(withId, const ExportOptions(contactId: true));
    expect(rows.first.last, 'contact_id');
  });

  test('normal vCard export writes TITLE and CATEGORIES', () {
    final text = utf8.decode(
      Codec.encode(people, Format.vcf, const ExportOptions()),
    );
    expect(text, contains('TITLE:Engineer'));
    expect(text, contains('CATEGORIES:Work,VIP'));
    final back = Codec.decode('x.vcf', Codec.encode(people, Format.vcf, const ExportOptions()));
    final ann = back.people.firstWhere((p) => p.name == 'Ann Lee');
    expect(ann.jobTitle, 'Engineer');
    expect(ann.groups, ['Work', 'VIP']);
  });

  test('JSON carries job title and groups', () {
    final text = utf8.decode(
      Codec.encode(people, Format.json, const ExportOptions()),
    );
    final first = (jsonDecode(text)['contacts'] as List).first as Map;
    expect(first['job_title'], 'Engineer');
    expect(first['groups'], ['Work', 'VIP']);
  });

  test('JSON round trip keeps job title and groups', () {
    final back = Codec.decode(
      'x.json',
      Codec.encode(people, Format.json, const ExportOptions()),
    );
    final ann = back.people.firstWhere((p) => p.name == 'Ann Lee');
    expect(ann.jobTitle, 'Engineer');
    expect(ann.groups, ['Work', 'VIP']);
  });

  group('tags', () {
    final tags = {
      people[0].id: ['Work', 'VIP'],
    };

    test('CSV leaves tags out by default and can include them', () {
      final off = Codec.table(
        people,
        const ExportOptions(),
        format: Format.csv,
        tags: tags,
      );
      expect(off.first, isNot(contains('Tags')));
      final on = Codec.table(
        people,
        const ExportOptions(includeTags: true),
        format: Format.csv,
        tags: tags,
      );
      expect(on.first, contains('Tags'));
      expect(on[1].last, 'Work ::: VIP');
    });

    test('XLSX includes a Tags column by default', () {
      final rows = Codec.table(people, const ExportOptions(), tags: tags);
      expect(rows.first, contains('Tags'));
    });

    test('no Tags column when nobody has tags', () {
      final rows = Codec.table(people, const ExportOptions(), tags: const {});
      expect(rows.first, isNot(contains('Tags')));
      final none = Codec.table(people, const ExportOptions());
      expect(none.first, isNot(contains('Tags')));
    });

    test('contact_id stays last with tags present', () {
      final withId = [people[0]..phoneId = '7'];
      final rows = Codec.table(
        withId,
        const ExportOptions(contactId: true),
        tags: tags,
      );
      expect(rows.first.last, 'contact_id');
    });

    test('vCard puts tags in CATEGORIES without repeating a group', () {
      final withGroup = [
        people[0].copy()..groups = ['Work'],
      ];
      final text = utf8.decode(
        Codec.encode(
          withGroup,
          Format.vcf,
          const ExportOptions(),
          tags: {withGroup[0].id: ['Work', 'VIP']},
        ),
      );
      expect(text, contains('CATEGORIES:Work,VIP'));
    });

    test('JSON carries tags', () {
      final text = utf8.decode(
        Codec.encode(people, Format.json, const ExportOptions(), tags: tags),
      );
      final first = (jsonDecode(text)['contacts'] as List).first as Map;
      expect(first['tags'], ['Work', 'VIP']);
    });
  });
}
