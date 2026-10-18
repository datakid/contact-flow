import 'dart:typed_data';

import 'package:archive/archive.dart';

class ZipTooLarge implements Exception {
  const ZipTooLarge();

  @override
  String toString() => 'ZipTooLarge';
}

class ZipGuard {
  static const maxUnpacked = 200 * 1024 * 1024;

  static Archive decode(Uint8List bytes, {int limit = maxUnpacked}) {
    final z = ZipDecoder().decodeBytes(bytes);
    var total = 0;
    for (final f in z.files) {
      total += f.size;
      if (total > limit) throw const ZipTooLarge();
    }
    return z;
  }
}
