import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:contact_flow/io/zip_guard.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List zipOf(int size) {
  final a = Archive();
  final data = utf8.encode('a' * size);
  a.addFile(ArchiveFile('xl/worksheets/sheet1.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

void main() {
  test('a zip within the limit decodes', () {
    expect(ZipGuard.decode(zipOf(512), limit: 1024).files.length, 1);
  });

  test('a zip over the limit is refused before unpacking', () {
    expect(
      () => ZipGuard.decode(zipOf(4096), limit: 1024),
      throwsA(isA<ZipTooLarge>()),
    );
  });

  test('the default limit is 200 MB', () {
    expect(ZipGuard.maxUnpacked, 200 * 1024 * 1024);
  });
}
