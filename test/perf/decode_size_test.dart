@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test(
    'a 1M-line text file decodes in time',
    () {
      final b = StringBuffer();
      String letters(int n) {
        final out = StringBuffer();
        var v = n;
        do {
          out.writeCharCode(97 + v % 26);
          v ~/= 26;
        } while (v > 0);
        return out.toString();
      }

      for (var i = 0; i < 1000000; i++) {
        b.writeln('Person ${letters(i)}, 055${i.toString().padLeft(7, '0')}');
      }
      final sw = Stopwatch()..start();
      final r = Codec.decode('big.txt', text(b.toString()));
      stdout.writeln(
        '1M-line txt: ${sw.elapsedMilliseconds}ms ${r.people.length}',
      );
      expect(r.people.length, 1000000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a 50k-row CSV decodes in time', () {
    final b = StringBuffer('Name,Phone\n');
    for (var i = 0; i < 50000; i++) {
      b.writeln('Person $i,055${i.toString().padLeft(7, '0')}');
    }
    final sw = Stopwatch()..start();
    final r = Codec.decode('big.csv', text(b.toString()));
    stdout.writeln('50k CSV: ${sw.elapsedMilliseconds}ms');
    expect(r.people.length, 50000);
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a 50k-row XLSX decodes in time', () {
    final people = [
      for (var i = 0; i < 50000; i++)
        Person(
          name: 'Person $i',
          phones: [PhoneEntry('055${i.toString().padLeft(7, '0')}')],
        ),
    ];
    final bytes = Codec.encode(people, Format.xlsx, const ExportOptions());
    final sw = Stopwatch()..start();
    final r = Codec.decode('big.xlsx', bytes);
    stdout.writeln('50k XLSX: ${sw.elapsedMilliseconds}ms');
    expect(r.people.length, 50000);
    expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'a vCard file with 5 MB of photos decodes in time',
    () {
      final photo = base64.encode(List<int>.generate(2500000, (i) => i % 251));
      String folded(String s) {
        final out = StringBuffer();
        for (var i = 0; i < s.length; i += 74) {
          out.write(i == 0 ? '' : '\r\n ');
          out.write(s.substring(i, i + 74 > s.length ? s.length : i + 74));
        }
        return out.toString();
      }

      final card = StringBuffer();
      for (final n in ['Ann', 'Bob']) {
        card.write('BEGIN:VCARD\r\nVERSION:3.0\r\nFN:$n\r\nTEL:0551234567\r\n');
        card.write('PHOTO;ENCODING=b;TYPE=JPEG:${folded(photo)}\r\n');
        card.write('END:VCARD\r\n');
      }
      final sw = Stopwatch()..start();
      final r = Codec.decode('photos.vcf', text(card.toString()));
      stdout.writeln('5MB vCard: ${sw.elapsedMilliseconds}ms');
      expect(r.people.length, 2);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
