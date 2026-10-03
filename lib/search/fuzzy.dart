import 'dart:math';

import 'package:lpinyin/lpinyin.dart';

import '../models/person.dart';
import 'fold.dart';

class Hit {
  final Person person;
  final double score;
  final List<(int, int)> nameRanges;
  final String? matchedPhone;
  final String? reason;

  const Hit(
    this.person,
    this.score, {
    this.nameRanges = const [],
    this.matchedPhone,
    this.reason,
  });
}

class _Syllable {
  final int charStart;
  final int charEnd;
  final int pyStart;
  final int pyEnd;
  const _Syllable(this.charStart, this.charEnd, this.pyStart, this.pyEnd);
}

class _Entry {
  final Person p;
  final String name;
  final String folded;
  final List<int> map;
  final List<String> words;
  final List<int> wordStarts;
  final String pinyin;
  final String pinyinInitials;
  final List<_Syllable> syllables;
  final String skeleton;
  final bool arabic;
  final List<String> phoneDigits;
  final String extras;

  _Entry({
    required this.p,
    required this.name,
    required this.folded,
    required this.map,
    required this.words,
    required this.wordStarts,
    required this.pinyin,
    required this.pinyinInitials,
    required this.syllables,
    required this.skeleton,
    required this.arabic,
    required this.phoneDigits,
    required this.extras,
  });

  factory _Entry.of(Person p) {
    final name = p.displayName;
    final f = Fold.withMap(name);
    final words = <String>[];
    final starts = <int>[];
    for (final m in RegExp(
      r'[^\s,;:/\\|_\-\.\(\)\[\]"@+]+',
    ).allMatches(f.text)) {
      words.add(m.group(0)!);
      starts.add(m.start);
    }
    var py = '';
    var ini = '';
    final syl = <_Syllable>[];
    if (Fold.hasCjk(name)) {
      final b = StringBuffer();
      final ib = StringBuffer();
      var i = 0;
      for (final r in name.runes) {
        final ch = String.fromCharCode(r);
        final len = ch.length;
        if (Fold.isCjk(r)) {
          final s = PinyinHelper.getPinyinE(
            ch,
            defPinyin: '',
          ).toLowerCase().replaceAll('ü', 'v').trim();
          if (s.isNotEmpty) {
            final st = b.length;
            b.write(s);
            syl.add(_Syllable(i, i + len, st, b.length));
            ib.write(s[0]);
          }
        } else {
          final fl = Fold.basic(ch).replaceAll(RegExp(r'\s'), '');
          if (fl.isNotEmpty) {
            final st = b.length;
            b.write(fl);
            syl.add(_Syllable(i, i + len, st, b.length));
          }
        }
        i += len;
      }
      py = b.toString();
      ini = ib.toString();
    }
    final ar = Fold.hasArabic(name);
    final skel = ar
        ? Fold.arabicSkeleton(f.text).replaceAll(' ', '')
        : Fold.latinSkeleton(f.text).replaceAll(' ', '');
    return _Entry(
      p: p,
      name: name,
      folded: f.text,
      map: f.map,
      words: words,
      wordStarts: starts,
      pinyin: py,
      pinyinInitials: ini,
      syllables: syl,
      skeleton: skel,
      arabic: ar,
      phoneDigits: p.phones.map((x) => x.digits).toList(),
      extras: Fold.basic([...p.emails, p.org, p.note].join(' ')),
    );
  }

  (int, int) orig(int fs, int fe) {
    final a = map[min(fs, map.length - 1)];
    final b = map[min(fe, map.length - 1)];
    return (a, max(a, b));
  }
}

class _TokenMatch {
  final double score;
  final List<(int, int)> ranges;
  final String? phone;
  final String? reason;
  const _TokenMatch(
    this.score, [
    this.ranges = const [],
    this.phone,
    this.reason,
  ]);
}

class FuzzyIndex {
  List<_Entry> _entries = const [];

  int get size => _entries.length;

  void build(List<Person> people) {
    _entries = people.map(_Entry.of).toList(growable: false);
  }

  List<Hit> search(String query, {int limit = 100000}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final fq = Fold.basic(q);
    final tokens = Fold.words(fq);
    if (tokens.isEmpty) return const [];
    final qDigits = Phones.digits(q);
    final digitQuery =
        qDigits.length >= 3 && RegExp(r'^[\s\d+\-\.\(\)٠-٩۰-۹]+$').hasMatch(q);
    final joined = tokens.join();
    final out = <Hit>[];
    for (final e in _entries) {
      if (digitQuery) {
        final m = _phone(e, qDigits);
        if (m != null) {
          out.add(Hit(e.p, m.score, matchedPhone: m.phone, reason: 'phone'));
        }
        continue;
      }
      var total = 0.0;
      final ranges = <(int, int)>[];
      String? phone;
      String? reason;
      var ok = true;
      for (final t in tokens) {
        final m = _token(e, t);
        if (m == null) {
          ok = false;
          break;
        }
        total += m.score;
        ranges.addAll(m.ranges);
        phone ??= m.phone;
        reason ??= m.reason;
      }
      if (!ok && tokens.length > 1) {
        final m = _token(e, joined);
        if (m != null && m.score >= 60) {
          ok = true;
          total = m.score * tokens.length * 0.9;
          ranges
            ..clear()
            ..addAll(m.ranges);
        }
      }
      if (!ok) continue;
      var score = total / tokens.length;
      if (e.folded.startsWith(fq)) score += 12;
      if (e.folded == fq) score += 20;
      score -= min(8, e.name.length / 12);
      out.add(
        Hit(
          e.p,
          score,
          nameRanges: _merge(ranges),
          matchedPhone: phone,
          reason: reason,
        ),
      );
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.person.displayName.compareTo(b.person.displayName);
    });
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  _TokenMatch? _phone(_Entry e, String qd) {
    double best = 0;
    String? num;
    for (var i = 0; i < e.phoneDigits.length; i++) {
      final d = e.phoneDigits[i];
      if (d.isEmpty) continue;
      double s = 0;
      if (d == qd) {
        s = 120;
      } else if (d.endsWith(qd)) {
        s = 100;
      } else if (d.startsWith(qd)) {
        s = 95;
      } else if (d.contains(qd)) {
        s = 85;
      } else if (qd.length >= 6) {
        final dist = _bestSubstringDistance(qd, d);
        if (dist <= 1) s = 55 - dist * 10;
      }
      if (s > best) {
        best = s;
        num = e.p.phones[i].number;
      }
    }
    return best > 0 ? _TokenMatch(best, const [], num, 'phone') : null;
  }

  _TokenMatch? _token(_Entry e, String t) {
    _TokenMatch? best;
    void consider(_TokenMatch m) {
      if (best == null || m.score > best!.score) best = m;
    }

    for (var i = 0; i < e.words.length; i++) {
      final w = e.words[i];
      final st = e.wordStarts[i];
      if (w == t) {
        consider(_TokenMatch(100, [e.orig(st, st + w.length)]));
      } else if (w.startsWith(t)) {
        consider(
          _TokenMatch(86 + 8 * t.length / w.length, [
            e.orig(st, st + t.length),
          ]),
        );
      }
    }
    if (best != null && best!.score >= 86) return best;

    final idx = e.folded.indexOf(t);
    if (idx >= 0) {
      consider(
        _TokenMatch(66 + min(10, t.length * 2).toDouble(), [
          e.orig(idx, idx + t.length),
        ]),
      );
    }

    if (e.pinyin.isNotEmpty && _isLatin(t)) {
      final pi = e.pinyin.indexOf(t);
      if (pi >= 0) {
        final atSyl = e.syllables.any((s) => s.pyStart == pi);
        consider(
          _TokenMatch(
            atSyl ? (pi == 0 ? 90 : 82) : 64,
            _pyRanges(e, pi, pi + t.length),
            null,
            'pinyin',
          ),
        );
      }
      if (t.length >= 2 && e.pinyinInitials.contains(t)) {
        final ii = e.pinyinInitials.indexOf(t);
        final cjk = e.syllables
            .where((s) => e.pinyin.length > s.pyStart)
            .where((s) => Fold.isCjk(e.name.codeUnitAt(s.charStart)))
            .toList();
        final r = <(int, int)>[];
        for (var k = ii; k < ii + t.length && k < cjk.length; k++) {
          r.add((cjk[k].charStart, cjk[k].charEnd));
        }
        consider(_TokenMatch(ii == 0 ? 80 : 70, r, null, 'pinyin'));
      }
      if (t.length >= 6 && best == null) {
        final d = _bestSubstringDistance(t, e.pinyin);
        if (d <= (t.length >= 9 ? 2 : 1)) {
          consider(_TokenMatch(52 - d * 8.0, const [], null, 'pinyin'));
        }
      }
    }

    if (best == null || best!.score < 60) {
      final maxEd = t.length >= 8 ? 2 : (t.length >= 3 ? 1 : 0);
      if (maxEd > 0) {
        for (var i = 0; i < e.words.length; i++) {
          final w = e.words[i];
          final st = e.wordStarts[i];
          final cut = w.length > t.length + 1 ? w.substring(0, t.length) : w;
          final d = _damerau(t, cut, maxEd);
          if (d <= maxEd) {
            final full = cut.length == w.length;
            consider(
              _TokenMatch(
                (full ? 62 : 56) - d * 9.0 + min(6, t.length).toDouble(),
                [e.orig(st, st + cut.length)],
                null,
                'fuzzy',
              ),
            );
          }
        }
      }
    }

    if (best == null && t.length >= 3) {
      final tArabic = Fold.hasArabic(t);
      if (tArabic != e.arabic && e.skeleton.length >= 2) {
        final ts = (tArabic ? Fold.arabicSkeleton(t) : Fold.latinSkeleton(t))
            .replaceAll(' ', '');
        if (ts.length >= 2) {
          final sk = e.skeleton;
          if (sk.contains(ts)) {
            consider(
              _TokenMatch(
                sk.startsWith(ts) ? 58 : 48,
                const [],
                null,
                'translit',
              ),
            );
          } else if (ts.length >= 4 && _bestSubstringDistance(ts, sk) <= 1) {
            consider(const _TokenMatch(40, [], null, 'translit'));
          }
        }
      }
    }

    if (best == null && t.length >= 2) {
      final r = _subsequence(e.folded, t);
      if (r != null) {
        consider(
          _TokenMatch(
            30 - min(15, r.$2 / 2),
            r.$1.map((x) => e.orig(x, x + 1)).toList(),
            null,
            'fuzzy',
          ),
        );
      }
    }

    if (best == null) {
      if (t.length >= 3 && e.extras.contains(t)) {
        consider(const _TokenMatch(45, [], null, 'details'));
      } else {
        final td = Phones.digits(t);
        if (td.length >= 3 && td.length == t.length) {
          final m = _phone(e, td);
          if (m != null) {
            consider(_TokenMatch(m.score * 0.7, const [], m.phone, 'phone'));
          }
        }
      }
    }
    return best;
  }

  static bool _isLatin(String t) => RegExp(r'^[a-z0-9]+$').hasMatch(t);

  List<(int, int)> _pyRanges(_Entry e, int ps, int pe) {
    final r = <(int, int)>[];
    for (final s in e.syllables) {
      if (s.pyEnd > ps && s.pyStart < pe) r.add((s.charStart, s.charEnd));
    }
    return r;
  }

  static (List<int>, int)? _subsequence(String hay, String needle) {
    final pos = <int>[];
    var j = 0;
    for (var i = 0; i < hay.length && j < needle.length; i++) {
      if (hay[i] == needle[j]) {
        pos.add(i);
        j++;
      }
    }
    if (j < needle.length) return null;
    final spread = pos.last - pos.first - needle.length + 1;
    if (spread > needle.length * 3 + 4) return null;
    return (pos, spread);
  }

  static int _damerau(String a, String b, int maxD) {
    if ((a.length - b.length).abs() > maxD) return maxD + 1;
    final n = a.length, m = b.length;
    var prev2 = List<int>.filled(m + 1, 0);
    var prev = List<int>.generate(m + 1, (j) => j);
    var cur = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= n; i++) {
      cur[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          v = min(v, prev2[j - 2] + 1);
        }
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > maxD) return maxD + 1;
      final t = prev2;
      prev2 = prev;
      prev = cur;
      cur = t;
    }
    return prev[m];
  }

  static int _bestSubstringDistance(String needle, String hay) {
    final n = needle.length, m = hay.length;
    if (m == 0) return n;
    var prev = List<int>.filled(m + 1, 0);
    var cur = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= n; i++) {
      cur[0] = i;
      for (var j = 1; j <= m; j++) {
        final cost = needle.codeUnitAt(i - 1) == hay.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev.reduce(min);
  }

  static List<(int, int)> _merge(List<(int, int)> r) {
    if (r.length < 2) return r;
    final s = [...r]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <(int, int)>[s.first];
    for (final x in s.skip(1)) {
      final l = out.last;
      if (x.$1 <= l.$2) {
        out[out.length - 1] = (l.$1, max(l.$2, x.$2));
      } else {
        out.add(x);
      }
    }
    return out;
  }
}
