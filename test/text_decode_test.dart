import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/text_decode.dart';
import 'package:contact_flow/io/vcard.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

List<String> namesOf(String file) => Codec.decode(
  file,
  fixture(file),
).people.map((p) => p.displayName).toList();

void main() {
  test('a Windows-1256 file that is mostly digits decodes as Arabic', () {
    final text = TextDecode.bytes(fixture('cp1256_ar.csv'));
    expect(text, contains('محمد'));
    expect(text, contains('منى'));
    final names = namesOf('cp1256_ar.csv');
    expect(names, containsAll(['محمد', 'علي', 'سارة']));
  });

  test('a Windows-1252 file keeps its accented letters', () {
    final names = namesOf('cp1252_fr.csv');
    expect(names, containsAll(['René', 'Élodie', 'François', 'Zoé']));
  });

  test('one bad byte in a UTF-8 file does not turn it into latin1', () {
    final text = TextDecode.bytes(fixture('utf8_one_bad_byte.csv'));
    expect(text, contains('محمد'));
    expect('\uFFFD'.allMatches(text).length, 1);
  });

  test('a vCard 2.1 with quoted-printable Windows-1256 names', () {
    final names = namesOf('vcard21_cp1256.vcf');
    expect(names.single, contains('محمد'));
  });

  test('a vCard with raw Windows-1256 bytes', () {
    final names = namesOf('vcard21_cp1256_raw.vcf');
    expect(names.single, 'سارة');
  });

  test('a short Latin word with one accent decodes as Windows-1252', () {
    final b = Uint8List.fromList([0x43, 0x61, 0x66, 0xE9, 0x20, 0x31, 0x32]);
    expect(TextDecode.bytes(b), 'Café 12');
  });

  test('plain ASCII and valid UTF-8 are unchanged', () {
    final ascii = Uint8List.fromList('abc,123'.codeUnits);
    expect(TextDecode.bytes(ascii), 'abc,123');
    final u = Uint8List.fromList(utf8.encode('محمد'));
    expect(TextDecode.bytes(u), 'محمد');
  });

  test('named charsets', () {
    expect(TextDecode.charset([0xC7], 'windows-1256'), 'ا');
    expect(TextDecode.charset([0xE9], 'Windows-1252'), 'é');
    expect(TextDecode.charset([0xE9], 'ISO-8859-1'), 'é');
    expect(TextDecode.charset([0xD9, 0x85], 'UTF-8'), 'م');
    expect(TextDecode.charset([0x41], 'GB2312'), isNull);
  });

  test('a vCard with an unsupported quoted-printable charset is flagged', () {
    expect(
      VCard.undecodableCharset(
        'FN;CHARSET=GB2312;ENCODING=QUOTED-PRINTABLE:=CD=F5=CE=B0',
      ),
      'GB2312',
    );
    expect(
      VCard.undecodableCharset(
        'FN;CHARSET=windows-1256;ENCODING=QUOTED-PRINTABLE:=CD=F5',
      ),
      isNull,
    );
    expect(VCard.undecodableCharset('FN;CHARSET=GB2312:Ann'), isNull);
  });
}
