import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/search/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = [
    Person(
      name: 'محمد عبد الله',
      phones: [const PhoneEntry('+966 50 123 4567')],
    ),
    Person(name: 'أحمد الخطيب', phones: [const PhoneEntry('+971 55 765 4321')]),
    Person(name: '王伟', phones: [const PhoneEntry('+86 138 0013 8000')]),
    Person(name: '李小龙', phones: [const PhoneEntry('+86 139 1234 5678')]),
    Person(name: 'José Álvarez', phones: [const PhoneEntry('+34 612 345 678')]),
    Person(
      name: 'Jonathan Smith',
      phones: [const PhoneEntry('+1 415 555 0101')],
    ),
    Person(name: 'Mohammed Ali', phones: [const PhoneEntry('+44 7700 900123')]),
    Person(
      name: 'François Dubois',
      phones: [const PhoneEntry('+33 6 12 34 56 78')],
    ),
  ];
  final idx = FuzzyIndex()..build(people);
  String top(String q) {
    final r = idx.search(q);
    return r.isEmpty
        ? '∅'
        : r
              .take(3)
              .map(
                (h) =>
                    '${h.person.displayName}(${h.score.toStringAsFixed(0)},${h.reason})',
              )
              .join(' | ');
  }

  test('queries', () {
    for (final q in [
      'jose',
      'alvarez',
      'jonatan',
      'jhonathan',
      'smth',
      'francois',
      'محمد',
      'احمد',
      'الخطيب',
      'mohamed',
      'muhammad',
      'wang',
      'wangwei',
      'ww',
      'lxl',
      'xiaolong',
      '王',
      '0013',
      '415555',
      '٠١٠١',
      'smiht',
      'dubios',
      'ahmad',
      'xiaolng',
    ]) {
      // ignore: avoid_print
      print('$q -> ${top(q)}');
    }
  });
}
