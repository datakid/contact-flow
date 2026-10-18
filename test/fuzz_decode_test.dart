import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:flutter_test/flutter_test.dart';

const names = [
  'a.csv',
  'a.xlsx',
  'a.vcf',
  'a.json',
  'a.txt',
  'a.numbers',
  'a.xls',
  'a.tsv',
];

Uint8List mutate(Random rnd, Uint8List src) {
  final b = BytesBuilder();
  var data = src;
  switch (rnd.nextInt(4)) {
    case 0:
      data = Uint8List.sublistView(src, 0, rnd.nextInt(src.length + 1));
    case 1:
      final copy = Uint8List.fromList(src);
      if (copy.isNotEmpty) {
        for (var i = 0; i < 1 + rnd.nextInt(20); i++) {
          copy[rnd.nextInt(copy.length)] = rnd.nextInt(256);
        }
      }
      data = copy;
    case 2:
      final at = src.isEmpty ? 0 : rnd.nextInt(src.length);
      b.add(src.sublist(0, at));
      b.add(List<int>.generate(rnd.nextInt(64), (_) => rnd.nextInt(256)));
      b.add(src.sublist(at));
      data = b.toBytes();
    default:
      final at = src.isEmpty ? 0 : rnd.nextInt(src.length);
      b.add(src.sublist(at));
      b.add(src.sublist(0, at));
      data = b.toBytes();
  }
  return data;
}

void main() {
  test('500 random byte blobs never throw', () {
    final rnd = Random(42);
    for (var i = 0; i < 500; i++) {
      final bytes = Uint8List.fromList(
        List<int>.generate(rnd.nextInt(4096), (_) => rnd.nextInt(256)),
      );
      final name = names[rnd.nextInt(names.length)];
      expect(() => Codec.decode(name, bytes), returnsNormally, reason: name);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('500 corrupted real files never throw', () {
    final rnd = Random(7);
    final files = [
      for (final dir in ['test/corpus', 'test/fixtures'])
        for (final f in Directory(dir).listSync().whereType<File>())
          if (!f.path.contains('zip_bomb')) f,
    ];
    expect(files, isNotEmpty);
    for (var i = 0; i < 500; i++) {
      final f = files[rnd.nextInt(files.length)];
      final bytes = mutate(rnd, f.readAsBytesSync());
      final name = rnd.nextBool()
          ? f.uri.pathSegments.last
          : names[rnd.nextInt(names.length)];
      expect(
        () => Codec.decode(name, bytes),
        returnsNormally,
        reason: '${f.path} as $name',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
