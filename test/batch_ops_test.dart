import 'package:contact_flow/batch/batch_ops.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

Person p(String name, List<String> nums, {String org = ''}) =>
    Person(name: name, phones: nums.map(PhoneEntry.new).toList(), org: org);

void main() {
  test('run() never mutates originals and only returns changes', () {
    final a = p('ali hassan', ['050 111 2222']);
    final b = p('Bob', ['+1 415 555 0100']);
    final r = BatchOp.run(const CaseName(CaseMode.title), [a, b]);
    expect(a.name, 'ali hassan');
    expect(r.length, 1);
    expect(r.first.$2.name, 'Ali Hassan');
    expect(r.first.$2.id, a.id);
  });

  test('find & replace in names, case-insensitive, squashes spaces', () {
    final r = BatchOp.run(const ReplaceInName('ACME ', ''), [
      p('acme  John', []),
    ]);
    expect(r.single.$2.name, 'John');
  });

  test('prefix/suffix are idempotent', () {
    final op = const AffixName(prefix: 'Dr. ', suffix: ' (Work)');
    final once = BatchOp.run(op, [p('Lina', [])]).single.$2;
    expect(once.name, 'Dr. Lina (Work)');
    expect(BatchOp.run(op, [once]), isEmpty);
  });

  test('title case handles hyphens and apostrophes', () {
    expect(TextOps.title("o'NEIL jean-luc"), "O'Neil Jean-Luc");
  });

  test('template numbering', () {
    final op = const TemplateName('Client {n} {first}', start: 7, pad: 3);
    final r = BatchOp.run(op, [p('Sara Q', []), p('Omar', [])]);
    expect(r[0].$2.name, 'Client 007 Sara');
    expect(r[1].$2.name, 'Client 008 Omar');
  });

  test('template onlyEmpty leaves named contacts alone', () {
    final op = const TemplateName('Lead {n}', onlyEmpty: true);
    final r = BatchOp.run(op, [
      p('Named', ['1']),
      p('', ['0501234567']),
    ]);
    expect(r.length, 1);
    expect(r.single.$2.name, 'Lead 2');
  });

  test('swap first/last', () {
    expect(
      BatchOp.run(const SwapName(), [p('Mary Ann Smith', [])]).single.$2.name,
      'Smith Mary Ann',
    );
  });

  test('clean name strips edge emoji and invisible marks', () {
    expect(
      BatchOp.run(const CleanName(), [
        p('★ \u200FJohn  Doe ☺', []),
      ]).single.$2.name,
      'John Doe',
    );
  });

  test('add country code drops trunk zero, keeps existing +', () {
    final r = BatchOp.run(const AddCountryCode('+971'), [
      p('a', ['050 123 4567', '+44 20 7946 0000', '00966501234567']),
    ]).single.$2;
    expect(r.phones.map((e) => e.number).toList(), [
      '+971501234567',
      '+44 20 7946 0000',
      '+966501234567',
    ]);
  });

  test('add country code does not double-prefix', () {
    final r = BatchOp.run(const AddCountryCode('971'), [
      p('a', ['971501234567']),
    ]).single.$2;
    expect(r.phones.single.number, '+971501234567');
  });

  test('remove country code', () {
    final r = BatchOp.run(const RemoveCountryCode('971'), [
      p('a', ['+971 50 123 4567', '+1 415 555 0100']),
    ]).single.$2;
    expect(r.phones[0].number, '0501234567');
    expect(r.phones[1].number, '+1 415 555 0100');
  });

  test('prefix replace in numbers ignores separators', () {
    final r = BatchOp.run(const ReplaceInNumbers('050', '055'), [
      p('a', ['050-123-4567', '052 000 0000']),
    ]).single.$2;
    expect(r.phones[0].number, '0551234567');
    expect(r.phones[1].number, '052 000 0000');
  });

  test('format numbers', () {
    final src = [
      p('a', ['+1 (415) 555-0100']),
    ];
    expect(
      BatchOp.run(
        const FormatNumbers(NumFormat.e164),
        src,
      ).single.$2.phones.single.number,
      '+14155550100',
    );
    expect(
      BatchOp.run(
        const FormatNumbers(NumFormat.digits),
        src,
      ).single.$2.phones.single.number,
      '14155550100',
    );
    expect(
      BatchOp.run(
        const FormatNumbers(NumFormat.spaced),
        src,
      ).single.$2.phones.single.number,
      '+1 415 555 0100',
    );
  });

  test('dedupe numbers within a contact', () {
    final r = BatchOp.run(const DedupeNumbers(), [
      p('a', ['+971 50 123 4567', '0501234567', '0509999999']),
    ]).single.$2;
    expect(r.phones.length, 2);
  });

  test('company only-empty and notes append without duplicating', () {
    final r = BatchOp.run(const SetCompany('Acme', onlyEmpty: true), [
      p('a', [], org: 'Keep'),
      p('b', []),
    ]);
    expect(r.single.$2.org, 'Acme');
    final n1 = BatchOp.run(const SetNote('VIP'), [p('x', [])]).single.$2;
    expect(n1.note, 'VIP');
    expect(BatchOp.run(const SetNote('VIP'), [n1]), isEmpty);
  });
}
