import 'dart:io';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List corpus(String name) => File('test/corpus/$name').readAsBytesSync();

ImportResult decode(String name) => Codec.decode(name, corpus(name));

void main() {
  const issues = <String, ImportIssue>{
    'truncated.xlsx': ImportIssue.unreadable,
    'ole_as_xls.xls': ImportIssue.legacyExcel,
    'ole_as_csv.csv': ImportIssue.unreadable,
    'pdf_as_csv.csv': ImportIssue.unreadable,
    'png_as_csv.csv': ImportIssue.unreadable,
    'zip_bomb.xlsx': ImportIssue.tooLarge,
    'empty.csv': ImportIssue.empty,
    'bom_only.csv': ImportIssue.empty,
    'vcard_gb2312_qp.vcf': ImportIssue.unsupportedCharset,
  };

  issues.forEach((name, issue) {
    test('$name reports $issue and no contacts', () {
      final r = decode(name);
      expect(r.people, isEmpty);
      expect(r.issue, issue);
    });
  });

  test('UTF-16 without a BOM is read', () {
    final names = decode('utf16le_no_bom.csv').people.map((p) => p.name);
    expect(names, ['Ann', 'Bob']);
  });

  test('old Mac line endings are rows', () {
    final names = decode('old_mac_cr.csv').people.map((p) => p.name);
    expect(names, ['Ann', 'Bob']);
  });

  test('a quoted field after leading spaces keeps its comma', () {
    final p = decode('quoted_after_space.csv').people.single;
    expect(p.phones.length, 1);
    expect(p.note, 'hello, world');
  });

  test('a quoted field can span several lines', () {
    final people = decode('multiline_field.csv').people;
    expect(people.length, 2);
    expect(people.first.note, 'line one\nline two');
  });

  test('vCard 2.1 with quoted-printable Arabic', () {
    final p = decode('vcard21_qp_arabic.vcf').people.single;
    expect(p.name, 'محمد');
    expect(p.phones.length, 1);
  });

  test('iPhone style vCard with grouped properties and a photo', () {
    final p = decode('iphone_style.vcf').people.single;
    expect(p.name, 'John Smith');
    expect(p.phones.length, 2);
    expect(p.emails, ['john@example.com']);
    expect(p.org, 'Acme');
  });

  test('Samsung style vCard 2.1', () {
    final p = decode('samsung_style.vcf').people.single;
    expect(p.name, 'Ahmed Ali');
    expect(p.phones.length, 2);
  });

  test('Google contacts CSV keeps company, title and labels', () {
    final people = decode('google_contacts.csv').people;
    final jane = people.firstWhere((p) => p.name == 'Jane Doe');
    expect(jane.org, 'Acme');
    expect(jane.jobTitle, 'Engineer');
    expect(jane.groups, ['Family']);
    expect(people.map((p) => p.name), contains('Sam Lee'));
  });

  test('Outlook CSV keeps the job title and categories', () {
    final people = decode('outlook.csv').people;
    expect(people.length, 2);
    final sam = people.firstWhere((p) => p.name == 'Sam Lee');
    expect(sam.jobTitle, 'Pharmacist');
    expect(sam.org, 'Globex');
    expect(sam.groups, ['Friends', 'Work']);
  });
}
