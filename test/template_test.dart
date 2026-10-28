import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:contact_flow/domain/sheet_template.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/tabular.dart';
import 'package:contact_flow/io/xlsx.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/import_issues.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List zipOf(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, content) {
    final data = utf8.encode(content);
    a.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String inline(String ref, String value) =>
    '<c r="$ref" t="inlineStr"><is><t>$value</t></is></c>';

String quoted(List<String> row) =>
    row.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

const ole2 = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

const expectedColumns = [
  Col.name,
  Col.phone,
  Col.phone,
  Col.email,
  Col.org,
  Col.note,
  Col.alias,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final codes = L.langs.keys.toList();

  group('template files', () {
    for (final code in codes) {
      final l = L(code);

      test('headers are classified as the app expects ($code)', () {
        final columns = Codec.templateColumns(
          headers: SheetTemplate.headers(l),
        );
        final m = Tabular.detect([columns]);
        expect(m.hasHeader, isTrue);
        expect(m.columns, expectedColumns);
      });

      for (final f in SheetTemplate.formats) {
        test('blank ${f.name} template is recognised as empty ($code)', () {
          final bytes = SheetTemplate.build(f, l);
          final r = Codec.decode(SheetTemplate.fileName(f), bytes);
          expect(r.people, isEmpty);
          expect(r.issue, ImportIssue.headerOnly);
        });

        test('filled ${f.name} template imports every row ($code)', () {
          final columns = Codec.templateColumns(
            headers: SheetTemplate.headers(l),
          );
          final rows = [
            columns,
            [
              'Sara Ahmed',
              '+201001234567',
              '',
              'sara@example.com',
              'Acme',
              'first note',
              'Sally, Dr. Sara',
            ],
            ['', '0501234567; 0559876543', '', '', '', '', ''],
            ['Omar', '', '', 'omar@example.com', '', '', ''],
            ['No contact details', '', '', '', '', '', ''],
          ];
          final bytes = f == Format.csv
              ? text('${rows.map(quoted).join('\r\n')}\r\n')
              : Xlsx.write(rows, textColumns: true);
          final r = Codec.decode(SheetTemplate.fileName(f), bytes);
          expect(r.issue, ImportIssue.none);
          expect(r.people.length, 3);
          final first = r.people.first;
          expect(first.name, 'Sara Ahmed');
          expect(first.phones.single.number, '+201001234567');
          expect(first.emails, ['sara@example.com']);
          expect(first.org, 'Acme');
          expect(first.note, 'first note');
          expect(first.aliases.length, 2);
          expect(r.people[1].phones.length, 2);
          expect(r.people[2].emails, ['omar@example.com']);
        });
      }
    }

    test(
      'xlsx template keeps its guide on a second sheet that is not read',
      () {
        final l = L('en');
        final bytes = SheetTemplate.build(Format.xlsx, l);
        final columns = Codec.templateColumns(
          headers: SheetTemplate.headers(l),
        );
        expect(Xlsx.read(bytes), [columns]);
      },
    );

    test('csv template is a BOM and a single header line', () {
      final bytes = SheetTemplate.build(Format.csv, L('en'));
      expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
      expect(
        utf8.decode(bytes.skip(3).toList()),
        'Name,Phone 1,Phone 2,Email,Company,Note,Alias\r\n',
      );
    });

    test('only csv and xlsx templates exist', () {
      for (final f in Format.values) {
        if (f == Format.csv || f == Format.xlsx) continue;
        expect(() => Codec.template(f), throwsArgumentError);
      }
    });

    test('file names use the export extension', () {
      expect(SheetTemplate.fileName(Format.xlsx), endsWith('.xlsx'));
      expect(SheetTemplate.fileName(Format.csv), endsWith('.csv'));
    });

    test('sheet names are sanitised and kept unique', () {
      const raw = "Bad:/Name?[x]'";
      final bytes = Xlsx.write(
        [
          ['A'],
        ],
        sheetName: raw,
        guide: const XlsxSheet(raw, [
          ['x'],
        ]),
      );
      expect(Xlsx.read(bytes), [
        ['A'],
      ]);
    });

    test('every new string exists in every language', () {
      final wanted = L
          .keysFor('en')
          .where(
            (k) =>
                k.startsWith('tpl') ||
                k.startsWith('issue_') ||
                k.startsWith('getTemplate'),
          )
          .toSet();
      expect(wanted.length, greaterThan(20));
      for (final code in codes) {
        expect(L.keysFor(code).containsAll(wanted), isTrue, reason: code);
      }
    });
  });

  group('wrong files never crash the importer', () {
    final random = Uint8List.fromList(
      List<int>.generate(300, (i) => (i * 37 + 11) % 256),
    );
    final workbook = Xlsx.write([
      ['Name', 'Phone'],
      ['Ali', '+201001234567'],
    ]);
    final cases = <String, (String, Uint8List, Object)>{
      'random bytes named xlsx': (
        'x.xlsx',
        random,
        anyOf(ImportIssue.noContacts, ImportIssue.noColumns),
      ),
      'random bytes named csv': (
        'x.csv',
        random,
        anyOf(ImportIssue.noContacts, ImportIssue.noColumns),
      ),
      'pdf': ('a.pdf', text('%PDF-1.7\n1 0 obj'), ImportIssue.unreadable),
      'png': (
        'a.png',
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ImportIssue.unreadable,
      ),
      'jpeg': (
        'a.jpg',
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
        ImportIssue.unreadable,
      ),
      'legacy xls': (
        'old.xls',
        Uint8List.fromList([...ole2, 0, 0, 0, 0]),
        ImportIssue.legacyExcel,
      ),
      'ole2 that is not xls': (
        'old.doc',
        Uint8List.fromList([...ole2, 0, 0, 0, 0]),
        ImportIssue.unreadable,
      ),
      'zero bytes': ('e.csv', Uint8List(0), ImportIssue.empty),
      'zero bytes xlsx': ('e.xlsx', Uint8List(0), ImportIssue.empty),
      'whitespace only': ('w.csv', text('  \n\n  \n'), ImportIssue.empty),
      'unrelated columns': (
        'p.csv',
        text('Product,Price,Qty\nApple,1.5,10\nPear,2,4\n'),
        ImportIssue.noColumns,
      ),
      'name column only': (
        'n.csv',
        text('Name,Company\nAli,Acme\n'),
        ImportIssue.noColumns,
      ),
      'phone column but empty cells': (
        'e.csv',
        text('Name,Phone\nAli,\nSara,\n'),
        ImportIssue.noContacts,
      ),
      'broken json': ('c.json', text('{"a": '), ImportIssue.noContacts),
      'json of numbers': ('c.json', text('[1,2,3]'), ImportIssue.noContacts),
      'zip that is not a workbook': (
        'letter.docx',
        zipOf({'word/document.xml': '<doc/>'}),
        ImportIssue.unreadable,
      ),
      'workbook without worksheets': (
        'w.xlsx',
        zipOf({
          'xl/workbook.xml':
              '<workbook><sheets><sheet name="A" sheetId="1" r:id="rId9"/></sheets></workbook>',
        }),
        ImportIssue.empty,
      ),
      'text file named xlsx': (
        'c.xlsx',
        text('Name,Phone\nAli,+201001234567\n'),
        ImportIssue.none,
      ),
      'workbook named csv': ('c.csv', workbook, ImportIssue.none),
      'workbook named txt': ('c.txt', workbook, ImportIssue.none),
    };
    cases.forEach((label, c) {
      test(label, () {
        late ImportResult r;
        expect(() => r = Codec.decode(c.$1, c.$2), returnsNormally);
        expect(r.fileName, c.$1);
        expect(r.issue, c.$3);
        if (c.$3 == ImportIssue.none) {
          expect(r.people.length, 1);
          expect(r.people.single.phones.single.number, '+201001234567');
        } else {
          expect(r.people, isEmpty);
        }
      });
    });

    test('every failure reads as a clear message in every language', () {
      for (final code in codes) {
        final l = L(code);
        for (final issue in ImportIssue.values) {
          if (issue == ImportIssue.none) continue;
          final r = ImportResult(
            const [],
            Format.csv,
            '',
            issue: issue,
            fileName: 'my.csv',
          );
          final line = ImportIssues.line(l, r);
          expect(line, contains('my.csv'), reason: '$code ${issue.name}');
          expect(line, isNot(startsWith('issue_')));
        }
      }
    });

    test('failed results are described and suggest the template', () {
      final l = L('en');
      final results = [
        ImportResult.failed('a.pdf'),
        const ImportResult(
          [],
          Format.csv,
          '',
          issue: ImportIssue.legacyExcel,
          fileName: 'b.xls',
        ),
      ];
      expect(ImportIssues.failures(results).length, 2);
      expect(ImportIssues.describe(l, results), contains('a.pdf'));
      expect(ImportIssues.describe(l, results), contains('b.xls'));
      expect(ImportIssues.suggestsTemplate(results), isTrue);
      expect(
        ImportIssues.suggestsTemplate([
          const ImportResult(
            [],
            Format.csv,
            '',
            issue: ImportIssue.legacyExcel,
          ),
        ]),
        isFalse,
      );
    });
  });

  group('malformed spreadsheet internals', () {
    test('absurd column references are skipped instead of freezing', () {
      final bytes = zipOf({
        'xl/worksheets/sheet1.xml':
            '<worksheet><sheetData>'
            '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}${inline('ZZZZZZZZZZ1', 'boom')}</row>'
            '<row r="2">${inline('A2', 'Ali')}${inline('B2', '+201001234567')}</row>'
            '</sheetData></worksheet>',
      });
      final r = Codec.decode('x.xlsx', bytes);
      expect(r.people.length, 1);
      expect(r.people.single.name, 'Ali');
    });

    test('empty shared strings keep later indexes aligned', () {
      final bytes = zipOf({
        'xl/sharedStrings.xml':
            '<sst><si><t>Name</t></si><si/><si><t>Phone</t></si>'
            '<si><r><t>Al</t></r><r><t>i</t></r><rPh sb="0" eb="1"><t>ZZ</t></rPh></si>'
            '<si><t>+201001234567</t></si></sst>',
        'xl/worksheets/sheet1.xml':
            '<worksheet><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>2</v></c></row>'
            '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2" t="s"><v>4</v></c></row>'
            '</sheetData></worksheet>',
      });
      final r = Codec.decode('x.xlsx', bytes);
      expect(r.people.single.name, 'Ali');
      expect(r.people.single.phones.single.number, '+201001234567');
    });

    test('huge character references are dropped instead of throwing', () {
      final bytes = zipOf({
        'xl/worksheets/sheet1.xml':
            '<worksheet><sheetData>'
            '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>'
            '<row r="2">${inline('A2', 'Al&#99999999;i&#xFFFFFFFF;')}${inline('B2', '+201001234567')}</row>'
            '</sheetData></worksheet>',
      });
      final r = Codec.decode('x.xlsx', bytes);
      expect(r.people.single.name, 'Ali');
    });

    test('numeric phone cells keep every digit', () {
      final bytes = zipOf({
        'xl/worksheets/sheet1.xml':
            '<worksheet><sheetData>'
            '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>'
            '<row r="2">${inline('A2', 'Ali')}<c r="B2"><v>201001234567</v></c></row>'
            '</sheetData></worksheet>',
      });
      final r = Codec.decode('x.xlsx', bytes);
      expect(r.people.single.phones.single.number, contains('201001234567'));
    });
  });

  group('import fixes', () {
    test('arabic export headers re-import with the company column', () {
      final l = L('ar');
      final people = [
        Person(
          name: 'سارة أحمد',
          phones: [const PhoneEntry('+201001234567')],
          org: 'شركة النور',
          note: 'ملاحظة',
        ),
      ];
      for (final f in [Format.csv, Format.xlsx]) {
        final bytes = Codec.encode(
          people,
          f,
          const ExportOptions(includeNote: true),
          headers: SheetTemplate.headers(l),
        );
        final r = Codec.decode('a.${f.exportExt}', bytes);
        expect(r.people.single.name, 'سارة أحمد', reason: f.name);
        expect(r.people.single.org, 'شركة النور', reason: f.name);
        expect(r.people.single.note, 'ملاحظة', reason: f.name);
      }
    });

    test('arabic last name and organisation headers are recognised', () {
      final m = Tabular.detect([
        ['العائلة', 'مؤسسة', 'الهاتف'],
      ]);
      expect(m.columns, [Col.last, Col.org, Col.phone]);
    });

    test('names starting with a formula character survive csv', () {
      final people = [
        Person(name: '-John', phones: [const PhoneEntry('+201001234567')]),
        Person(name: '@mona', phones: [const PhoneEntry('+201001234568')]),
        Person(name: '=sum', phones: [const PhoneEntry('+201001234569')]),
      ];
      final bytes = Codec.encode(people, Format.csv, const ExportOptions());
      final r = Codec.decode('a.csv', bytes);
      expect(
        r.people.map((p) => p.name).toList(),
        unorderedEquals(['-John', '@mona', '=sum']),
      );
    });

    test('commit keeps job title, starred and groups', () async {
      SharedPreferences.setMockInitialValues({'lang': 'en'});
      final s = AppState();
      await s.init(openStore: false);
      final incoming = Person(
        name: 'Dana',
        phones: [const PhoneEntry('+201001234567')],
        jobTitle: 'CTO',
        starred: true,
        groups: ['VIP'],
      );
      final n = await s.commit(
        s.plan([
          ImportResult([incoming], Format.vcf, ''),
        ]),
      );
      expect(n, 1);
      final saved = s.people.firstWhere((p) => p.name == 'Dana');
      expect(saved.jobTitle, 'CTO');
      expect(saved.starred, isTrue);
      expect(saved.groups, ['VIP']);
    });

    test('plan ignores failed files when counting formats', () async {
      SharedPreferences.setMockInitialValues({'lang': 'en'});
      final s = AppState();
      await s.init(openStore: false);
      final plan = s.plan([
        ImportResult.failed('broken.xlsx'),
        ImportResult(
          [
            Person(
              name: 'Dana',
              phones: [const PhoneEntry('+201001234567')],
              source: 'a.csv',
            ),
          ],
          Format.csv,
          '',
        ),
      ]);
      expect(plan.incoming.length, 1);
      expect(plan.formats.keys.toList(), [Format.csv]);
      expect(plan.formats[Format.csv], 1);
    });
  });
}
