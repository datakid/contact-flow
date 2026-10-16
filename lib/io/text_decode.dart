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
    return _auto(data);
  }

  static String? charset(List<int> b, String name) {
    final n = name.toLowerCase().replaceAll('_', '-').trim();
    if (n == 'utf-8' || n == 'utf8') {
      return utf8.decode(b, allowMalformed: true);
    }
    if (n.contains('1256') || n == 'arabic' || n == 'cp1256') {
      return _table(b, _cp1256);
    }
    if (n.contains('1252') || n == 'cp1252') {
      return _table(b, _cp1252);
    }
    final compact = n.replaceAll('-', '');
    if (n.contains('8859') || compact.contains('latin')) {
      return latin1.decode(b, allowInvalid: true);
    }
    if (compact == 'usascii' || compact == 'ascii') {
      return latin1.decode(b, allowInvalid: true);
    }
    return null;
  }

  static String _auto(Uint8List data) {
    var high = 0, good = 0;
    var i = 0;
    while (i < data.length) {
      final c = data[i];
      if (c < 0x80) {
        i++;
        continue;
      }
      final len = _seqLen(data, i);
      if (len == 0) {
        high++;
        i++;
      } else {
        high += len;
        good += len;
        i += len;
      }
    }
    if (high == 0 || good >= high * 0.99) {
      return utf8.decode(data, allowMalformed: true);
    }
    var arabic = 0, latin = 0, run = 0, runArabic = 0;
    void endRun() {
      if (run >= 2) {
        arabic += runArabic;
      } else if (run == 1 && runArabic == 0) {
        latin++;
      }
      run = 0;
      runArabic = 0;
    }

    for (final c in data) {
      if (c >= 0x80) {
        run++;
        if (_arabicLetter(c)) runArabic++;
      } else if (run > 0) {
        endRun();
      }
    }
    if (run > 0) endRun();
    return _table(data, arabic > latin ? _cp1256 : _cp1252);
  }

  static int _seqLen(Uint8List d, int i) {
    final c = d[i];
    bool cont(int k, [int lo = 0x80, int hi = 0xBF]) =>
        i + k < d.length && d[i + k] >= lo && d[i + k] <= hi;
    if (c >= 0xC2 && c <= 0xDF) return cont(1) ? 2 : 0;
    if (c >= 0xE0 && c <= 0xEF) {
      final lo = c == 0xE0 ? 0xA0 : 0x80;
      final hi = c == 0xED ? 0x9F : 0xBF;
      return cont(1, lo, hi) && cont(2) ? 3 : 0;
    }
    if (c >= 0xF0 && c <= 0xF4) {
      final lo = c == 0xF0 ? 0x90 : 0x80;
      final hi = c == 0xF4 ? 0x8F : 0xBF;
      return cont(1, lo, hi) && cont(2) && cont(3) ? 4 : 0;
    }
    return 0;
  }

  static bool _arabicLetter(int c) =>
      (c >= 0xC1 && c <= 0xD6) ||
      (c >= 0xD8 && c <= 0xDF) ||
      c == 0xE1 ||
      (c >= 0xE3 && c <= 0xE6) ||
      c == 0xEC ||
      c == 0xED;

  static String _table(List<int> b, List<int> high) {
    final out = StringBuffer();
    for (final c in b) {
      if (c < 0x80) {
        out.writeCharCode(c);
      } else if (c < 0xA0) {
        out.writeCharCode(high[c - 0x80]);
      } else if (identical(high, _cp1252)) {
        out.writeCharCode(c);
      } else {
        out.writeCharCode(_cp1256Upper[c - 0xA0]);
      }
    }
    return out.toString();
  }

  static const _cp1252 = <int>[
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
    0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
  ];

  static const _cp1256 = <int>[
    0x20AC, 0x067E, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688,
    0x06AF, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x06A9, 0x2122, 0x0691, 0x203A, 0x0153, 0x200C, 0x200D, 0x06BA,
  ];

  static const _cp1256Upper = <int>[
    0x00A0, 0x060C, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
    0x00A8, 0x00A9, 0x06BE, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
    0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
    0x00B8, 0x00B9, 0x061B, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x061F,
    0x06C1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627,
    0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F,
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00D7,
    0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643,
    0x00E0, 0x0644, 0x00E2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00E7,
    0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0649, 0x064A, 0x00EE, 0x00EF,
    0x064B, 0x064C, 0x064D, 0x064E, 0x00F4, 0x064F, 0x0650, 0x00F7,
    0x0651, 0x00F9, 0x0652, 0x00FB, 0x00FC, 0x200E, 0x200F, 0x06D2,
  ];

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
}
