import 'package:contact_flow/io/tabular.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final google = [
    [
      'First Name',
      'Middle Name',
      'Last Name',
      'Phonetic First Name',
      'Name Prefix',
      'Nickname',
      'File As',
      'Organization Name',
      'Organization Title',
      'Organization Department',
      'Birthday',
      'Notes',
      'Photo',
      'Labels',
      'E-mail 1 - Label',
      'E-mail 1 - Value',
      'Phone 1 - Label',
      'Phone 1 - Value',
    ],
    [
      'Jane',
      '',
      'Doe',
      '',
      'Dr.',
      'JD',
      '',
      'Acme',
      'Engineer',
      'Sales',
      '',
      'note',
      '',
      '* myContacts ::: Family ::: Gym',
      'Home',
      'jane@example.com',
      'Mobile',
      '+966551234567',
    ],
  ];

  final outlook = [
    [
      'Title',
      'First Name',
      'Middle Name',
      'Last Name',
      'Suffix',
      'Company',
      'Department',
      'Job Title',
      'Business Street',
      'Mobile Phone',
      'E-mail Address',
      'Categories',
    ],
    [
      'Dr.',
      'Sam',
      '',
      'Lee',
      '',
      'Globex',
      'Ops',
      'Pharmacist',
      '1 Main St',
      '0551234567',
      'sam@example.com',
      'Friends;Work',
    ],
  ];

  test('Google organization columns map to company and job title', () {
    final m = Tabular.detect(google);
    final p = Tabular.toPeople(google, m, 'google.csv').single;
    expect(p.org, 'Acme');
    expect(p.jobTitle, 'Engineer');
    expect(p.displayName, 'Jane Doe');
  });

  test('Google labels become groups without system labels', () {
    final m = Tabular.detect(google);
    final p = Tabular.toPeople(google, m, 'google.csv').single;
    expect(p.groups, ['Family', 'Gym']);
  });

  test('Outlook Title is a prefix when Job Title is present', () {
    final m = Tabular.detect(outlook);
    final p = Tabular.toPeople(outlook, m, 'outlook.csv').single;
    expect(p.jobTitle, 'Pharmacist');
    expect(p.org, 'Globex');
  });

  test('Outlook categories become groups', () {
    final m = Tabular.detect(outlook);
    final p = Tabular.toPeople(outlook, m, 'outlook.csv').single;
    expect(p.groups, ['Friends', 'Work']);
  });

  test('a lone Title column is still a job title', () {
    final rows = [
      ['Name', 'Title', 'Phone'],
      ['Ann', 'Manager', '0551234567'],
    ];
    final p = Tabular.toPeople(rows, Tabular.detect(rows), 'x.csv').single;
    expect(p.jobTitle, 'Manager');
  });

  test('header words map to tags in several languages', () {
    for (final h in ['Labels', 'Group Membership', 'Categories', 'Tags']) {
      expect(Tabular.classifyHeader(h), Col.tags, reason: h);
    }
    expect(Tabular.classifyHeader('标签'), Col.tags);
    expect(Tabular.classifyHeader('Étiquettes'), Col.tags);
    expect(Tabular.classifyHeader('Etiquetas'), Col.tags);
    expect(Tabular.classifyHeader('تصنيف'), Col.tags);
  });

  test('phone type labels are still labels', () {
    expect(Tabular.classifyHeader('Phone 1 - Label'), Col.label);
    expect(Tabular.classifyHeader('Type'), Col.label);
  });

  test('splitTags drops system labels and repeats', () {
    expect(
      Tabular.splitTags('* myContacts ::: * starred ::: Family ::: Family'),
      ['Family'],
    );
  });
}
