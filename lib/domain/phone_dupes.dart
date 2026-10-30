import '../models/person.dart';

class PhoneDupes {
  static (List<Person> fresh, List<Person> already) split(
    Iterable<Person> candidates,
    Iterable<Person> onPhone,
  ) {
    final index = <String, List<Person>>{};
    for (final o in onPhone) {
      for (final k in o.matchKeys) {
        (index[k] ??= []).add(o);
      }
    }
    final fresh = <Person>[];
    final already = <Person>[];
    for (final p in candidates) {
      var found = false;
      for (final k in p.matchKeys) {
        for (final o in index[k] ?? const <Person>[]) {
          if (o.sharesIdentity(p)) {
            found = true;
            break;
          }
        }
        if (found) break;
      }
      (found ? already : fresh).add(p);
    }
    return (fresh, already);
  }
}
