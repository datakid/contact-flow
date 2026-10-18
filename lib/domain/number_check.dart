import '../models/person.dart';
import '../phone/phone_key.dart';

class NumberInfo {
  final bool international;
  final int digits;
  final bool letters;
  final String key;
  const NumberInfo(this.international, this.digits, this.letters, this.key);

  bool get odd => digits < 5 || digits > 15 || letters;
  bool get local => !international && !odd;
}

class NumberCheck {
  static const _blocks = [0x0660, 0x06F0, 0xFF10, 0x0966];
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _ext = RegExp(
    r'(?:x|ext\.?|#)\s*[0-9\u0660-\u0669\u06F0-\u06F9\uFF10-\uFF19]+\s*$',
    caseSensitive: false,
  );

  static int _digit(int r) {
    if (r >= 0x30 && r <= 0x39) return r - 0x30;
    if (r < 0x660) return -1;
    for (final b in _blocks) {
      if (r >= b && r <= b + 9) return r - b;
    }
    return -1;
  }

  static bool _isLetter(int r) {
    if (r < 0x80) return (r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A);
    return _letter.hasMatch(String.fromCharCode(r));
  }

  static NumberInfo inspect(String raw) {
    final t = raw.trim();
    var plus = false;
    var first = true;
    var letters = false;
    var headDigits = 0;
    var inExt = false;
    final all = StringBuffer();
    for (final r in t.runes) {
      if (first) {
        first = false;
        if (r == 0x2B || r == 0xFF0B) plus = true;
      }
      final d = _digit(r);
      if (d >= 0) {
        all.writeCharCode(0x30 + d);
        if (!inExt) headDigits++;
      } else if (r == 0x23) {
        inExt = true;
      } else if (_isLetter(r)) {
        letters = true;
      }
    }
    final digits = all.toString();
    if (letters) {
      final m = _ext.firstMatch(t);
      if (m != null) {
        final head = t.substring(0, m.start);
        letters = false;
        headDigits = 0;
        for (final r in head.runes) {
          if (_digit(r) >= 0) {
            headDigits++;
          } else if (_isLetter(r)) {
            letters = true;
          }
        }
      }
    }
    final international =
        digits.isNotEmpty &&
        (plus || (digits.startsWith('00') && digits.length > 9));
    return NumberInfo(international, headDigits, letters, PhoneKey.key(t));
  }
}

class NumberStats {
  static const local = 1;
  static const odd = 2;
  static const shared = 4;

  static const empty = NumberStats({}, 0, 0, 0);

  final Map<String, int> flags;
  final int localCount;
  final int oddCount;
  final int sharedCount;
  const NumberStats(
    this.flags,
    this.localCount,
    this.oddCount,
    this.sharedCount,
  );

  bool has(Person p, int flag) => ((flags[p.id] ?? 0) & flag) != 0;

  static NumberStats of(List<Person> people) {
    final flags = <String, int>{};
    final owners = <String, int>{};
    final keysOf = <List<String>>[];
    for (final p in people) {
      var f = 0;
      final keys = <String>[];
      for (final e in p.phones) {
        if (e.number.trim().isEmpty) continue;
        final info = NumberCheck.inspect(e.number);
        if (info.odd) {
          f |= odd;
        } else if (!info.international) {
          f |= local;
        }
        if (info.key.isNotEmpty && !keys.contains(info.key)) {
          keys.add(info.key);
        }
      }
      for (final k in keys) {
        owners[k] = (owners[k] ?? 0) + 1;
      }
      keysOf.add(keys);
      if (f != 0) flags[p.id] = f;
    }
    var localN = 0;
    var oddN = 0;
    var sharedN = 0;
    for (var i = 0; i < people.length; i++) {
      final id = people[i].id;
      var f = flags[id] ?? 0;
      for (final k in keysOf[i]) {
        if ((owners[k] ?? 0) > 1) {
          f |= shared;
          break;
        }
      }
      if (f == 0) continue;
      flags[id] = f;
      if ((f & local) != 0) localN++;
      if ((f & odd) != 0) oddN++;
      if ((f & shared) != 0) sharedN++;
    }
    return NumberStats(flags, localN, oddN, sharedN);
  }
}
