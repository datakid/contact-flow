mkdir -p /tmp/prof
cat > test/zz_prof_test.dart <<'DART'
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/text_decode.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prof', () {
    for (final n in [10000, 20000, 40000, 80000]) {
      final b = StringBuffer();
      for (var i = 0; i < n; i++) {
        b.writeln('Person $i 055${(i % 10000000).toString().padLeft(7, '0')}');
      }
      final bytes = Uint8List.fromList(utf8.encode(b.toString()));
      var sw = Stopwatch()..start();
      final text = TextDecode.bytes(bytes);
      stdout.writeln('n=$n textdecode ${sw.elapsedMilliseconds}ms');
      sw = Stopwatch()..start();
      var c = 0;
      for (final line in text.split('\n')) {
        c += Phones.extract(line).length;
      }
      stdout.writeln('n=$n extract ${sw.elapsedMilliseconds}ms $c');
      sw = Stopwatch()..start();
      final people = [
        for (var i = 0; i < n; i++)
          Person(name: 'Person $i', phones: [PhoneEntry('0550000000')]),
      ];
      stdout.writeln('n=$n person ${sw.elapsedMilliseconds}ms ${people.length}');
      sw = Stopwatch()..start();
      final r = Codec.decode('big.txt', bytes);
      stdout.writeln('n=$n decode ${sw.elapsedMilliseconds}ms ${r.people.length}');
    }
  });
}
DART
timeout 600 flutter test test/zz_prof_test.dart --reporter expanded
