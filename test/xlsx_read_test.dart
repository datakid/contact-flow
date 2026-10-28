import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List zipOf(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, content) {
    final data = utf8.encode(content);
    a.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String inline(String ref, String value, [String p = '']) =>
    '<${p}c r="$ref" t="inlineStr"><${p}is><${p}t>$value</${p}t></${p}is></${p}c>';

String workbookXml(List<String> names, [String p = '']) {
  final b = StringBuffer('<${p}workbook xmlns:r="urn:r"><${p}sheets>');
  for (var i = 0; i < names.length; i++) {
    b.write(
      '<${p}sheet name="${names[i]}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    );
  }
  b.write('</${p}sheets></${p}workbook>');
  return b.toString();
}

String relsXml(int n) {
  final b = StringBuffer('<Relationships>');
  for (var i = 1; i <= n; i++) {
    b.write(
      '<Relationship Id="rId$i" Type="worksheet" Target="worksheets/sheet$i.xml"/>',
    );
  }
  b.write('</Relationships>');
  return b.toString();
}

String sheetXml(List<String> rows, [String p = '']) =>
    '<${p}worksheet><${p}sheetData>${rows.join()}</${p}sheetData></${p}worksheet>';

Uint8List book(
  List<String> names,
  List<String> sheets, {
  String p = '',
  Map<String, String> extra = const {},
}) => zipOf({
  'xl/workbook.xml': workbookXml(names, p),
  'xl/_rels/workbook.xml.rels': relsXml(names.length),
  for (var i = 0; i < sheets.length; i++)
    'xl/worksheets/sheet${i + 1}.xml': sheets[i],
  ...extra,
});

void main() {
  test('reads a workbook whose XML uses a namespace prefix', () {
    final bytes = book(
      ['Data'],
      [
        sheetXml([
          '<x:row r="1"><x:c r="A1" t="s"><x:v>0</x:v></x:c>'
              '<x:c r="B1" t="s"><x:v>1</x:v></x:c></x:row>',
          '<x:row r="2"><x:c r="A2" t="s"><x:v>2</x:v></x:c>'
              '<x:c r="B2"><x:v>551234567</x:v></x:c></x:row>',
        ], 'x:'),
      ],
      p: 'x:',
      extra: {
        'xl/sharedStrings.xml':
            '<x:sst><x:si><x:t>Name</x:t></x:si><x:si><x:t>Phone</x:t></x:si>'
            '<x:si><x:t>Ann</x:t></x:si></x:sst>',
      },
    );
    expect(Xlsx.read(bytes), [
      ['Name', 'Phone'],
      ['Ann', '551234567'],
    ]);
  });

  test('a self-closing row does not swallow the next row', () {
    final bytes = book(
      ['Data'],
      [
        sheetXml([
          '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>',
          '<row r="2"/>',
          '<row r="3">${inline('A3', 'Ann')}${inline('B3', '0551234567')}</row>',
          '<row r="4"></row>',
        ]),
      ],
    );
    expect(Xlsx.read(bytes), [
      ['Name', 'Phone'],
      ['Ann', '0551234567'],
    ]);
  });

  test('contacts on the second sheet are found and the sheet is named', () {
    final bytes = book(
      ['Notes', 'Contacts'],
      [
        sheetXml([
          '<row r="1">${inline('A1', 'Notes')}</row>',
          '<row r="2">${inline('A2', 'hello')}</row>',
        ]),
        sheetXml([
          '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>',
          '<row r="2">${inline('A2', 'Ann')}${inline('B2', '0551234567')}</row>',
        ]),
      ],
    );
    final r = Codec.decode('x.xlsx', bytes);
    expect(r.people.single.displayName, 'Ann');
    expect(r.detail, contains('Contacts'));
  });

  test('a first sheet with a phone column is used even when it is empty', () {
    final bytes = book(
      ['Contacts', 'Other'],
      [
        sheetXml([
          '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>',
        ]),
        sheetXml([
          '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>',
          '<row r="2">${inline('A2', 'Bob')}${inline('B2', '0551234567')}</row>',
        ]),
      ],
    );
    final r = Codec.decode('x.xlsx', bytes);
    expect(r.people, isEmpty);
  });

  test('sheet names come back in workbook order', () {
    final bytes = book(
      ['One', 'Two'],
      [
        sheetXml(['<row r="1">${inline('A1', 'a')}</row>']),
        sheetXml(['<row r="1">${inline('A1', 'b')}</row>']),
      ],
    );
    expect(Xlsx.readSheets(bytes).map((s) => s.name).toList(), ['One', 'Two']);
  });

  const styles =
      '<styleSheet><numFmts count="1">'
      '<numFmt numFmtId="164" formatCode="0000000000"/></numFmts>'
      '<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="164" '
      'applyNumberFormat="1"/></cellXfs></styleSheet>';

  Uint8List phoneBook(String style) => book(
    ['Data'],
    [
      sheetXml([
        '<row r="1">${inline('A1', 'Name')}${inline('B1', 'Phone')}</row>',
        '<row r="2">${inline('A2', 'Ann')}'
            '<c r="B2"$style><v>551234567</v></c></row>',
      ]),
    ],
    extra: {'xl/styles.xml': styles},
  );

  test('a zero-padded number format restores the leading zero', () {
    expect(Xlsx.read(phoneBook(' s="1"')).last, ['Ann', '0551234567']);
  });

  test('a number without that format is left alone', () {
    expect(Xlsx.read(phoneBook(' s="0"')).last, ['Ann', '551234567']);
    expect(Xlsx.read(phoneBook('')).last, ['Ann', '551234567']);
  });
}
