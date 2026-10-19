import '../models/person.dart';
import 'fuzzy.dart';
import 'number_pattern.dart';

class PatternSearch {
  final Map<Person, (String, List<PhoneForms>)> _cache = Map.identity();

  void invalidate() => _cache.clear();

  List<PhoneForms> formsOf(Person p) {
    final sig = p.phones.map((e) => e.number).join('\u0000');
    final hit = _cache[p];
    if (hit != null && hit.$1 == sig) return hit.$2;
    final forms = [for (final e in p.phones) PhoneForms.of(e.number)];
    _cache[p] = (sig, forms);
    return forms;
  }

  static bool hasGroup(Person p, String tag) =>
      p.groups.any((g) => g.toLowerCase() == tag);

  List<Hit> search(NumberQuery q, Iterable<Person> people, FuzzyIndex fuzzy) {
    final text = q.text;
    Map<Person, Hit>? textHits;
    if (text.isNotEmpty) {
      textHits = Map.identity();
      for (final h in fuzzy.search(text)) {
        textHits[h.person] = h;
      }
    }
    final out = <Hit>[];
    for (final p in people) {
      final textHit = textHits?[p];
      if (textHits != null && textHit == null) continue;
      final forms = formsOf(p);
      bool tag(String t) => hasGroup(p, t);
      int? best;
      String? number;
      if (q.hasNumberAtoms) {
        for (final f in forms) {
          final s = q.score([f], hasTag: tag);
          if (s != null && (best == null || s > best)) {
            best = s;
            number = f.raw;
          }
        }
      } else {
        best = q.score(const [], hasTag: tag);
      }
      if (best == null) continue;
      out.add(
        Hit(
          p,
          best * 100 + (textHit?.score ?? 0) / 10,
          matchedPhone: number,
          reason: number == null ? 'tag' : 'phone',
          nameRanges: textHit?.nameRanges ?? const [],
        ),
      );
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.person.displayName.compareTo(b.person.displayName);
    });
    return out;
  }
}
