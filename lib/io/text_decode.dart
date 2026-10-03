import 'dart:convert';
import 'dart:typed_data';

class TextDecode {
  static String bytes(Uint8List b) {
    if (b.length >= 2) {
      if (b[0] == 0xFF && b[1] == 0xFE) {
        return _utf16(b.sublist(2), little: true);
      }
      if (b[0] == 0xFE && b[1] == 0xFF) {
        return _utf16(b.sublist(2), little: false);
      }
    }
    var data = b;
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      data = b.sublist(3);
    }
    if (_looksUtf16(data)) {
      return _utf16(data, little: data.length > 1 && data[1] == 0);
    }
    try {
      return utf8.decode(data);
    } catch (_) {
      return _cp1252OrLatin1(data);
    }
  }

  static bool _looksUtf16(Uint8List b) {
    if (b.length < 8) return false;
    var evenZero = 0, oddZero = 0;
    final n = b.length < 400 ? b.length : 400;
    for (var i = 0; i < n; i++) {
      if (b[i] == 0) {
        if (i.isEven) {
          evenZero++;
        } else {
          oddZero++;
        }
      }
    }
    return evenZero > n / 4 || oddZero > n / 4;
  }

  static String _utf16(Uint8List b, {required bool little}) {
    final units = <int>[];
    for (var i = 0; i + 1 < b.length; i += 2) {
      units.add(little ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  static String _cp1252OrLatin1(Uint8List b) =>
      latin1.decode(b, allowInvalid: true);
}
