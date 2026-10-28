cat > test/zz_prof_test.dart <<'DART'
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prof', () {
    for (final n in [5000, 10000, 10001, 10002, 20000, 100000]) {
      final b = StringBuffer();
      for (var i = 0; i < n; i++) {
        b.writeln('Person $i, 055${(i % 10000000).toString().padLeft(7, '0')}');
      }
      final bytes = Uint8List.fromList(utf8.encode(b.toString()));
      final r = Codec.decode('big.txt', bytes);
      stdout.writeln('n=$n people=${r.people.length} fmt=${r.format} issue=${r.issue}');
      if (r.people.length != n) {
        stdout.writeln('last=${r.people.last.name} ${r.people.last.phones.length}');
      }
    }
  });
}
DART
timeout 600 flutter test test/zz_prof_test.dart --reporter expanded
