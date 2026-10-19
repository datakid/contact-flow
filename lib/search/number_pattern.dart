import '../models/person.dart';
import '../phone/phone_key.dart';

enum DigitMode { anywhere, ends, starts, contains }

sealed class QueryAtom {
  const QueryAtom();
}

class NumberAtom extends QueryAtom {
  final String pattern;
  final bool plus;
  const NumberAtom(this.pattern, {this.plus = false});

  bool get wildcard => pattern.contains('*') || pattern.contains('?');

  @override
  bool operator ==(Object other) =>
      other is NumberAtom && other.pattern == pattern && other.plus == plus;

  @override
  int get hashCode => Object.hash(pattern, plus);

  @override
  String toString() => 'NumberAtom(${plus ? '+' : ''}$pattern)';
}

class TagAtom extends QueryAtom {
  final String tag;
  const TagAtom(this.tag);

  @override
  bool operator ==(Object other) => other is TagAtom && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => 'TagAtom($tag)';
}

class TextAtom extends QueryAtom {
  final String text;
  const TextAtom(this.text);

  @override
  bool operator ==(Object other) => other is TextAtom && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextAtom($text)';
}

class PhoneForms {
  final String raw;
  final String saved;
  final String national;
  final String e164;
  const PhoneForms(this.raw, this.saved, this.national, this.e164);

  static final _digits = RegExp(r'[^0-9]');

  static PhoneForms of(String raw) {
    final ext = PhoneKey.extension(raw);
    var body = Phones.asciiDigits(raw);
    if (ext.isNotEmpty) {
      body = body.replaceFirst(
        RegExp(r'\s*(?:x|ext\.?|#)\s*\d+\s*$', caseSensitive: false),
        '',
      );
    }
    final saved = body.replaceAll(_digits, '');
    final national = (PhoneKey.national(raw) ?? '').replaceAll(_digits, '');
    final e164 = (PhoneKey.e164(raw) ?? '').replaceAll(_digits, '');
    return PhoneForms(raw, saved, national, e164);
  }

  Iterable<String> get all sync* {
    if (saved.isNotEmpty) yield saved;
    if (national.isNotEmpty && national != saved) yield national;
    if (e164.isNotEmpty && e164 != saved && e164 != national) yield e164;
  }
}

class NumberQuery {
  final String source;
  final List<List<QueryAtom>> alternatives;
  final DigitMode mode;
  const NumberQuery._(this.source, this.alternatives, this.mode);

  static const empty = NumberQuery._('', [], DigitMode.anywhere);

  bool get isEmpty => alternatives.isEmpty;

  bool get hasNumberAtoms => alternatives.any((a) => a.any((x) => x is NumberAtom));

  bool get hasTagAtoms => alternatives.any((a) => a.any((x) => x is TagAtom));

  bool get isPattern => hasNumberAtoms || hasTagAtoms;

  bool get digitsOnly =>
      alternatives.length == 1 &&
      alternatives.first.length == 1 &&
      alternatives.first.first is NumberAtom &&
      !(alternatives.first.first as NumberAtom).wildcard;

  String get text => [
    for (final a in alternatives.isEmpty ? const <QueryAtom>[] : alternatives.first)
      if (a is TextAtom) a.text,
  ].join(' ');

  static String normalizeChars(String raw) {
    final b = StringBuffer();
    for (final r in raw.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
      } else if (r >= 0xFF10 && r <= 0xFF19) {
        b.writeCharCode(0x30 + r - 0xFF10);
      } else if (r == 0x061F || r == 0xFF1F) {
        b.write('?');
      } else if (r == 0x060C || r == 0xFF0C || r == 0x3001) {
        b.write(',');
      } else if (r == 0xFF0A) {
        b.write('*');
      } else if (r == 0xFF03) {
        b.write('#');
      } else if (r == 0xFF0B) {
        b.write('+');
      } else if (r == 0x00A0 || r == 0x3000) {
        b.write(' ');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static final _wholeNumber = RegExp(r'^[+(]*[0-9][0-9\s\-().]*$');
  static final _numberToken = RegExp(r'^\+?[0-9*?\-().]+$');
  static final _patternish = RegExp(r'[0-9*?#]');

  static NumberQuery parse(String raw, {DigitMode mode = DigitMode.anywhere}) {
    final q = normalizeChars(raw).trim();
    if (q.isEmpty) return empty;
    if (_wholeNumber.hasMatch(q)) {
      final atom = _numberAtom(q.replaceAll(RegExp(r'\s+'), ''));
      return atom == null
          ? empty
          : NumberQuery._(raw, [
              [atom],
            ], mode);
    }
    final parts = q
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return empty;
    if (!parts.every(_patternish.hasMatch)) {
      final text = q.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return NumberQuery._(raw, [
        [TextAtom(text)],
      ], mode);
    }
    final alternatives = <List<QueryAtom>>[];
    for (final part in parts) {
      final atoms = <QueryAtom>[];
      final spaced = part.replaceAllMapped(RegExp(r'(?<=\S)#'), (_) => ' #');
      for (final token in spaced.split(RegExp(r'\s+'))) {
        final atom = _atom(token);
        if (atom != null) atoms.add(atom);
      }
      if (atoms.isNotEmpty) alternatives.add(atoms);
    }
    return alternatives.isEmpty
        ? empty
        : NumberQuery._(raw, alternatives, mode);
  }

  static QueryAtom? _atom(String token) {
    if (token.startsWith('#')) {
      final name = token.substring(1).trim().toLowerCase();
      return name.isEmpty ? null : TagAtom(name);
    }
    if (_numberToken.hasMatch(token) && RegExp(r'[0-9*?]').hasMatch(token)) {
      return _numberAtom(token);
    }
    return token.isEmpty ? null : TextAtom(token);
  }

  static NumberAtom? _numberAtom(String token) {
    final plus = token.startsWith('+');
    var p = token.replaceAll(RegExp(r'[+\-().\s]'), '');
    p = p.replaceAll(RegExp(r'\*+'), '*');
    if (p.isEmpty) return null;
    return NumberAtom(p, plus: plus);
  }

  static RegExp _glob(String pattern) {
    final b = StringBuffer('^');
    for (final c in pattern.split('')) {
      if (c == '*') {
        b.write(r'\d*');
      } else if (c == '?') {
        b.write(r'\d');
      } else {
        b.write(c);
      }
    }
    b.write(r'$');
    return RegExp(b.toString());
  }

  Iterable<String> _forms(NumberAtom a, PhoneForms f) =>
      a.plus ? (f.e164.isEmpty ? const [] : [f.e164]) : f.all;

  int _plainScore(String p, String t) {
    if (t == p) return 4;
    final ends = t.endsWith(p);
    final starts = t.startsWith(p);
    switch (mode) {
      case DigitMode.ends:
        return ends ? 3 : 0;
      case DigitMode.starts:
        return starts ? 2 : 0;
      case DigitMode.contains:
        return t.contains(p) ? 1 : 0;
      case DigitMode.anywhere:
        if (ends) return 3;
        if (starts) return 2;
        return t.contains(p) ? 1 : 0;
    }
  }

  int atomScore(NumberAtom a, PhoneForms f) {
    var best = 0;
    if (a.wildcard) {
      final re = _glob(a.pattern);
      for (final t in _forms(a, f)) {
        if (re.hasMatch(t)) return 3;
      }
      return 0;
    }
    for (final t in _forms(a, f)) {
      final s = _plainScore(a.pattern, t);
      if (s > best) best = s;
    }
    return best;
  }

  int? score(
    List<PhoneForms> numbers, {
    bool Function(String tag)? hasTag,
  }) {
    int? best;
    for (final alt in alternatives) {
      final numberAtoms = alt.whereType<NumberAtom>().toList();
      final tagAtoms = alt.whereType<TagAtom>().toList();
      if (numberAtoms.isEmpty && tagAtoms.isEmpty) continue;
      if (tagAtoms.isNotEmpty &&
          (hasTag == null || !tagAtoms.every((t) => hasTag(t.tag)))) {
        continue;
      }
      var altScore = tagAtoms.isEmpty ? 0 : 1;
      if (numberAtoms.isNotEmpty) {
        var bestNumber = 0;
        for (final f in numbers) {
          var sum = 0;
          var ok = true;
          for (final a in numberAtoms) {
            final s = atomScore(a, f);
            if (s == 0) {
              ok = false;
              break;
            }
            sum += s;
          }
          if (ok && sum > bestNumber) bestNumber = sum;
        }
        if (bestNumber == 0) continue;
        altScore += bestNumber;
      }
      if (best == null || altScore > best) best = altScore;
    }
    return best;
  }

  List<(int, int)> highlights(NumberAtom a, String digits) {
    if (digits.isEmpty) return const [];
    if (a.wildcard) return _globHighlights(a.pattern, digits);
    final i = switch (mode) {
      DigitMode.ends =>
        digits.endsWith(a.pattern) ? digits.length - a.pattern.length : -1,
      DigitMode.starts => digits.startsWith(a.pattern) ? 0 : -1,
      _ =>
        digits.endsWith(a.pattern)
            ? digits.length - a.pattern.length
            : digits.indexOf(a.pattern),
    };
    return i < 0 ? const [] : [(i, i + a.pattern.length)];
  }

  static List<(int, int)> _globHighlights(String pattern, String digits) {
    if (!_glob(pattern).hasMatch(digits)) return const [];
    final segs = pattern.split('*');
    final startAnchored = !pattern.startsWith('*');
    final endAnchored = !pattern.endsWith('*');
    final out = <(int, int)>[];
    var pos = 0;
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      if (seg.isEmpty) continue;
      int at;
      if (i == 0 && startAnchored) {
        at = 0;
      } else if (i == segs.length - 1 && endAnchored) {
        at = digits.length - seg.length;
      } else {
        at = _find(seg, digits, pos);
        if (at < 0) return const [];
      }
      out.add((at, at + seg.length));
      pos = at + seg.length;
    }
    return out;
  }

  static int _find(String seg, String digits, int from) {
    for (var i = from; i + seg.length <= digits.length; i++) {
      var ok = true;
      for (var k = 0; k < seg.length; k++) {
        if (seg[k] != '?' && seg[k] != digits[i + k]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }
}
