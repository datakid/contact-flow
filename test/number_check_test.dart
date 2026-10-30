import 'dart:math';

import 'package:contact_flow/domain/number_check.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/contact_list.dart';
import 'package:flutter_test/flutter_test.dart';

class _List extends ContactList {
  void load(List<Person> people) => replacePeople(people);
}

Person person(String name, List<String> numbers) =>
    Person(name: name, phones: [for (final n in numbers) PhoneEntry(n)]);

String kind(String raw) {
  final i = NumberCheck.inspect(raw);
  if (i.odd) return 'odd';
  return i.local ? 'local' : 'intl';
}

void main() {
  group('NumberCheck.inspect', () {
    const cases = <String, String>{
      '+20 100 123 4567': 'intl',
      '0100 123 4567': 'local',
      '(555) 123-4567': 'local',
      '+1 (555) 123-4567 x89': 'intl',
      '0020100123456': 'intl',
      '555 1234 ext 12': 'local',
      '555-1234#99': 'local',
      '٠١٠٠١٢٣٤٥٦٧': 'local',
      '+٢٠١٠٠١٢٣٤٥٦٧': 'intl',
      '00123': 'local',
      '12345': 'local',
      '123456789012345': 'local',
      '1-800-FLOWERS': 'odd',
      'N/A': 'odd',
      '911': 'odd',
      '1234': 'odd',
      '+12': 'odd',
      '1234567890123456': 'odd',
      '': 'odd',
    };
    cases.forEach((raw, expected) {
      test('"$raw" is $expected', () => expect(kind(raw), expected));
    });

    test('local and international forms of one number share a key', () {
      final keys = {
        for (final n in ['+201001234567', '01001234567', '٠١٠٠١٢٣٤٥٦٧'])
          NumberCheck.inspect(n).key,
      };
      expect(keys, {'001234567'});
    });

    test('agrees with Phones.key and Phones.clean on messy input', () {
      const alphabet = [
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '٠',
        '١',
        '٢',
        '٣',
        '۰',
        '۱',
        '۲',
        '０',
        '１',
        '२',
        '३',
        ' ',
        ' ',
        '(',
        ')',
        '-',
        '.',
        '/',
        '+',
        '＋',
        '\u00a0',
        '\t',
        'x',
        'X',
        '#',
        'e',
        'a',
        'é',
        'م',
        '王',
        ' ext ',
        'x ',
      ];
      final random = Random(7);
      for (var n = 0; n < 20000; n++) {
        final raw = [
          for (var i = random.nextInt(24); i > 0; i--)
            alphabet[random.nextInt(alphabet.length)],
        ].join();
        final info = NumberCheck.inspect(raw);
        expect(info.key, Phones.key(raw), reason: '"$raw"');
        expect(
          info.international,
          Phones.clean(raw).startsWith('+'),
          reason: '"$raw"',
        );
      }
    });
  });

  group('NumberStats', () {
    final a = person('A', ['+201001234567']);
    final b = person('B', ['01001234567']);
    final c = person('C', ['911']);
    final d = person('D', ['+966501112222']);
    final e = person('E', ['+447700900123', '+447700900123']);
    final f = person('F', ['1-800-FLOWERS']);
    final g = person('G', []);
    final h = person('H', ['', '  ']);
    final people = [a, b, c, d, e, f, g, h];

    test('counts contacts, not numbers', () {
      final s = NumberStats.of(people);
      expect(s.localCount, 1);
      expect(s.oddCount, 2);
      expect(s.sharedCount, 2);
    });

    test('flags the right contacts', () {
      final s = NumberStats.of(people);
      expect(s.has(a, NumberStats.shared), isTrue);
      expect(s.has(b, NumberStats.shared), isTrue);
      expect(s.has(b, NumberStats.local), isTrue);
      expect(s.has(c, NumberStats.odd), isTrue);
      expect(s.has(f, NumberStats.odd), isTrue);
      for (final p in [d, e, g, h]) {
        for (final flag in [
          NumberStats.local,
          NumberStats.odd,
          NumberStats.shared,
        ]) {
          expect(s.has(p, flag), isFalse, reason: p.name);
        }
      }
    });

    test('the same number twice on one contact is not shared', () {
      final s = NumberStats.of([e]);
      expect(s.sharedCount, 0);
    });

    test('an empty list has no problems', () {
      final s = NumberStats.of(const []);
      expect(s.localCount + s.oddCount + s.sharedCount, 0);
    });
  });

  group('ContactList number filters', () {
    final a = person('A', ['+201001234567']);
    final b = person('B', ['01001234567']);
    final c = person('C', ['911']);
    final d = person('D', ['+966501112222']);
    final f = person('F', ['1-800-FLOWERS']);

    Set<String> names(_List list) => {for (final p in list.visible) p.name};

    test('each filter shows only matching contacts', () {
      final list = _List()..load([a, b, c, d, f]);
      list.setFilter(ListFilter.noCountryCode);
      expect(names(list), {'B'});
      list.setFilter(ListFilter.oddNumber);
      expect(names(list), {'C', 'F'});
      list.setFilter(ListFilter.sharedNumber);
      expect(names(list), {'A', 'B'});
      list.clearFilters();
      expect(names(list), {'A', 'B', 'C', 'D', 'F'});
    });

    test('stats follow the list when people change', () {
      final list = _List()..load([a, b, c]);
      expect(list.numberStats.oddCount, 1);
      list.load([a, d]);
      expect(list.numberStats.oddCount, 0);
      expect(list.numberStats.sharedCount, 0);
      list.setFilter(ListFilter.sharedNumber);
      expect(names(list), isEmpty);
    });
  });

  test('stats for 10,000 contacts are fast', () {
    final people = [
      for (var i = 0; i < 10000; i++)
        Person(
          name: 'Person $i',
          phones: [
            PhoneEntry('+97150${(1000000 + i).toString()}'),
            if (i % 5 == 0) PhoneEntry('050${(2000000 + i).toString()}'),
            if (i % 50 == 0) const PhoneEntry('12'),
          ],
        ),
    ];
    final watch = Stopwatch()..start();
    final s = NumberStats.of(people);
    watch.stop();
    expect(s.localCount, 2000);
    expect(s.oddCount, 200);
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
