import '../models/person.dart';
import '../phone/phone_key.dart';

class SavedNumbers {
  final Map<String, List<String>> _byKey = {};

  SavedNumbers.of(Iterable<Person> people) {
    for (final p in people) {
      for (final e in p.phones) {
        final k = PhoneKey.key(e.number);
        if (k.isNotEmpty) (_byKey[k] ??= []).add(e.number);
      }
    }
  }

  bool has(String raw) {
    final k = PhoneKey.key(raw);
    if (k.isEmpty) return false;
    final list = _byKey[k];
    if (list == null) return false;
    return list.any((n) => PhoneKey.compatible(n, raw));
  }
}
