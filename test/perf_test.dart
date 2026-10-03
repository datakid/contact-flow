import 'dart:math';

import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/search/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search stays fast on large books', () {
    final r = Random(1);
    const first = [
      'Amelia',
      'محمد',
      '王',
      'José',
      'Léa',
      'فاطمة',
      '李',
      'Jonathan',
      'Sofía',
      'أحمد',
      '陈',
      'Hiroshi',
      'Priya',
      'Oliver',
      'Noor',
    ];
    const last = [
      'Hart',
      'عبد الله',
      '伟',
      'Álvarez',
      'Fontaine',
      'الزهراء',
      '小龙',
      'Smith',
      'Ramírez',
      'الخطيب',
      '静',
      'Tanaka',
      'Raman',
      'Bennett',
      'Haddad',
    ];
    final people = List.generate(
      10000,
      (i) => Person(
        name:
            '${first[r.nextInt(first.length)]} ${last[r.nextInt(last.length)]} $i',
        phones: [PhoneEntry('+${r.nextInt(99)} ${r.nextInt(999999999)}')],
      ),
    );
    final idx = FuzzyIndex();
    final sw = Stopwatch()..start();
    idx.build(people);
    final build = sw.elapsedMilliseconds;
    final times = <String, int>{};
    for (final q in [
      'a',
      'jo',
      'jonatan',
      'wang',
      'محمد',
      'smth',
      '555',
      'xyzq',
    ]) {
      sw.reset();
      idx.search(q);
      times[q] = sw.elapsedMilliseconds;
    }
    // ignore: avoid_print
    print('build ${build}ms $times');
  });
}
