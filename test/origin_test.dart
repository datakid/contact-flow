import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('a text line is kept as the original line', () {
    final r = Codec.decode('a.txt', bytes('Ann Lee 0551234567\n'));
    expect(r.people.single.origin, 'Ann Lee 0551234567');
  });

  test('a csv row is kept as the original row', () {
    final r = Codec.decode(
      'a.csv',
      bytes('Name,Phone\nAnn Lee,0551234567\n'),
    );
    expect(r.people.single.origin, 'Ann Lee | 0551234567');
  });

  test('a vCard keeps its lines but not its photo', () {
    final r = Codec.decode(
      'a.vcf',
      bytes(
        'BEGIN:VCARD\nVERSION:3.0\nFN:Ann Lee\nTEL:0551234567\nPHOTO;ENCODING=b:AAAA\nEND:VCARD\n',
      ),
    );
    final origin = r.people.single.origin;
    expect(origin, contains('FN:Ann Lee'));
    expect(origin, contains('TEL:0551234567'));
    expect(origin, isNot(contains('PHOTO')));
  });

  test('the original line is not saved with the contact', () {
    final r = Codec.decode('a.txt', bytes('Ann Lee 0551234567\n'));
    expect(r.people.single.toJson().containsKey('origin'), isFalse);
    expect(r.people.single.copy().origin, 'Ann Lee 0551234567');
  });
}
