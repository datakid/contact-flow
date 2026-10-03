import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('large batch timings', () {
    final people = List.generate(
      int.parse(const String.fromEnvironment('N', defaultValue: '1000')),
      (i) => Person(
        name: 'Person $i محمد 王伟',
        phones: [
          PhoneEntry('+1 415 ${(1000000 + i).toString().substring(1)}'),
          PhoneEntry('+44 20 7946 ${i % 10000}'),
        ],
        emails: ['p$i@x.com'],
      ),
    );
    final sw = Stopwatch()..start();
    final out = <String>[];
    for (final f in Format.values) {
      sw.reset();
      // ignore: avoid_print
      print('start ${f.name}');
      final b = Codec.encode(people, f, const ExportOptions());
      final enc = sw.elapsedMilliseconds;
      sw.reset();
      final r = Codec.decode('x.${f.exportExt}', Uint8List.fromList(b));
      // ignore: avoid_print
      print('${f.name}: enc ${enc}ms dec ${sw.elapsedMilliseconds}ms');
      out.add(
        '${f.name}: ${(b.length / 1e6).toStringAsFixed(1)}MB enc ${enc}ms dec ${sw.elapsedMilliseconds}ms n=${r.people.length}',
      );
    }
    // ignore: avoid_print
    print(out.join('\n'));
    expect(utf8.decode([0x41]), 'A');
  });
}
