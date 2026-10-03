import 'package:lpinyin/lpinyin.dart';

class Fold {
  static final Map<int, String> _latin = _buildLatin();

  static Map<int, String> _buildLatin() {
    const groups = {
      'a': 'àáâãäåāăąǎǟǡǻȁȃȧᶏạảấầẩẫậắằẳẵặ',
      'c': 'çćĉċč',
      'd': 'ďđ',
      'e': 'èéêëēĕėęěȅȇȩẹẻẽếềểễệ',
      'g': 'ĝğġģǧ',
      'h': 'ĥħ',
      'i': 'ìíîïĩīĭįıǐȉȋịỉ',
      'j': 'ĵ',
      'k': 'ķǩ',
      'l': 'ĺļľŀł',
      'n': 'ñńņňŉǹ',
      'o': 'òóôõöøōŏőǒǫǭȍȏȫȭȯȱọỏốồổỗộớờởỡợơ',
      'r': 'ŕŗř',
      's': 'śŝşšș',
      't': 'ţťŧț',
      'u': 'ùúûüũūŭůűųǔǖǘǚǜȕȗụủứừửữựư',
      'w': 'ŵ',
      'y': 'ýÿŷỳỵỷỹ',
      'z': 'źżž',
    };
    final m = <int, String>{};
    groups.forEach((k, v) {
      for (final r in v.runes) {
        m[r] = k;
      }
    });
    m['ß'.runes.first] = 'ss';
    m['æ'.runes.first] = 'ae';
    m['œ'.runes.first] = 'oe';
    m['þ'.runes.first] = 'th';
    m['ð'.runes.first] = 'd';
    m['ё'.runes.first] = 'е';
    m['й'.runes.first] = 'и';
    m['ά'.runes.first] = 'α';
    m['έ'.runes.first] = 'ε';
    m['ή'.runes.first] = 'η';
    m['ί'.runes.first] = 'ι';
    m['ό'.runes.first] = 'ο';
    m['ύ'.runes.first] = 'υ';
    m['ώ'.runes.first] = 'ω';
    m['ς'.runes.first] = 'σ';
    return m;
  }

  static const _arabicMap = {
    0x0622: 'ا',
    0x0623: 'ا',
    0x0625: 'ا',
    0x0671: 'ا',
    0x0672: 'ا',
    0x0673: 'ا',
    0x0649: 'ي',
    0x06CC: 'ي',
    0x064A: 'ي',
    0x0626: 'ي',
    0x0629: 'ه',
    0x06C0: 'ه',
    0x06D5: 'ه',
    0x0624: 'و',
    0x06A9: 'ك',
    0x06AF: 'ك',
  };

  static bool _isArabicMark(int r) =>
      (r >= 0x064B && r <= 0x065F) ||
      r == 0x0670 ||
      r == 0x0640 ||
      (r >= 0x06D6 && r <= 0x06ED) ||
      (r >= 0x0610 && r <= 0x061A);

  static bool _isCombining(int r) => r >= 0x0300 && r <= 0x036F;

  static bool isCjk(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0xF900 && r <= 0xFAFF);

  static bool isArabic(int r) =>
      (r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F);

  static bool hasCjk(String s) => s.runes.any(isCjk);
  static bool hasArabic(String s) => s.runes.any(isArabic);

  static String basic(String input) => withMap(input).text;

  static ({String text, List<int> map}) withMap(String input) {
    final b = StringBuffer();
    final map = <int>[];
    var offset = 0;
    for (final orig in input.runes) {
      final start = offset;
      offset += orig > 0xFFFF ? 2 : 1;
      final before = b.length;
      _foldRune(orig, b);
      for (var i = before; i < b.length; i++) {
        map.add(start);
      }
    }
    map.add(offset);
    return (text: b.toString(), map: map);
  }

  static void _foldRune(int orig, StringBuffer b) {
    final low = String.fromCharCode(orig).toLowerCase();
    for (final r in low.runes) {
      if (_isCombining(r) || _isArabicMark(r)) continue;
      if (r == 0x0130) {
        b.write('i');
        continue;
      }
      if (r >= 0xFF01 && r <= 0xFF5E) {
        b.write(String.fromCharCode(r - 0xFEE0).toLowerCase());
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
        continue;
      }
      if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
        continue;
      }
      final a = _arabicMap[r];
      if (a != null) {
        b.write(a);
        continue;
      }
      final l = _latin[r];
      if (l != null) {
        b.write(l);
        continue;
      }
      if (r == 0x2019 || r == 0x2018 || r == 0x27 || r == 0x60) continue;
      b.writeCharCode(r);
    }
  }

  static List<String> words(String folded) => folded
      .split(RegExp(r'[\s,;:/\\|_\-\.\(\)\[\]"@+]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  static String pinyin(String s) {
    if (!hasCjk(s)) return '';
    return PinyinHelper.getPinyinE(
      s,
      separator: ' ',
      defPinyin: '',
    ).toLowerCase().replaceAll('ü', 'v').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String pinyinInitials(String py) =>
      py.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).join();

  static const _arLatin = {
    'ب': 'b',
    'ت': 't',
    'ث': 'th',
    'ج': 'j',
    'ح': 'h',
    'خ': 'kh',
    'د': 'd',
    'ذ': 'dh',
    'ر': 'r',
    'ز': 'z',
    'س': 's',
    'ش': 'sh',
    'ص': 's',
    'ض': 'd',
    'ط': 't',
    'ظ': 'z',
    'غ': 'gh',
    'ف': 'f',
    'ق': 'k',
    'ك': 'k',
    'ل': 'l',
    'م': 'm',
    'ن': 'n',
    'ه': 'h',
    'پ': 'p',
    'چ': 'ch',
    'ژ': 'zh',
    'ڤ': 'v',
  };

  static String arabicSkeleton(String folded) {
    final b = StringBuffer();
    for (final ch in folded.split('')) {
      final m = _arLatin[ch];
      if (m != null) {
        b.write(m);
      } else if (ch == ' ') {
        b.write(' ');
      }
    }
    return _collapse(b.toString());
  }

  static String latinSkeleton(String folded) {
    var s = folded
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll('q', 'k')
        .replaceAll('c', 'k')
        .replaceAll('g', 'j')
        .replaceAll('kh', '\u0001')
        .replaceAll('gh', '\u0002')
        .replaceAll('jh', '\u0002')
        .replaceAll('sh', '\u0003')
        .replaceAll('th', '\u0004')
        .replaceAll('dh', '\u0005')
        .replaceAll('ph', 'f')
        .replaceAll(RegExp(r'[aeiouyw]'), '');
    s = s
        .replaceAll('\u0001', 'kh')
        .replaceAll('\u0002', 'gh')
        .replaceAll('\u0003', 'sh')
        .replaceAll('\u0004', 'th')
        .replaceAll('\u0005', 'dh');
    return _collapse(s);
  }

  static String _collapse(String s) {
    final b = StringBuffer();
    String? prev;
    for (final ch in s.split('')) {
      if (ch != prev || ch == ' ') b.write(ch);
      prev = ch;
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
