import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/search/fuzzy.dart';
import 'package:contact_flow/search/number_pattern.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/person_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const number = '0551234567';

  group('digit ranges for a number', () {
    List<(int, int)> r(String q) =>
        NumberQuery.parse(q).highlightsFor(number);

    test('ends with', () => expect(r('*67'), [(8, 10)]));
    test('plain digits at the end', () => expect(r('67'), [(8, 10)]));
    test('plain digits in the middle', () => expect(r('123'), [(4, 7)]));
    test('starts with', () => expect(r('055*'), [(0, 3)]));
    test('start and end', () => expect(r('05*67'), [(0, 2), (8, 10)]));
    test('question mark counts as a position', () {
      expect(r('05?1*'), [(0, 4)]);
    });
    test('alternatives are merged and sorted', () {
      expect(r('*67, 055*'), [(0, 3), (8, 10)]);
    });
    test('overlapping ranges are merged', () {
      expect(r('055* *55*'), [(0, 3)]);
    });
    test('no match gives no ranges', () => expect(r('*99'), isEmpty));
    test('a leading plus is not highlighted', () {
      expect(r('+966*'), isEmpty);
    });
    test('Arabic digits in the stored number still map', () {
      expect(
        NumberQuery.parse('*67').highlightsFor('٠٥٥١٢٣٤٥٦٧'),
        [(8, 10)],
      );
    });
  });

  group('mapping onto the shown text', () {
    test('spaces in the number are skipped', () {
      expect(digitRangesToText('055 123 4567', [(8, 10)]), [(10, 12)]);
    });

    test('a leading plus and dashes are skipped', () {
      expect(digitRangesToText('+966-50-123', [(0, 3)]), [(1, 4)]);
    });

    test('a range spanning a space covers it', () {
      expect(digitRangesToText('055 123', [(2, 4)]), [(2, 5)]);
    });

    test('ranges beyond the digits are dropped', () {
      expect(digitRangesToText('123', [(5, 7)]), isEmpty);
    });

    test('Arabic-Indic digits are counted', () {
      expect(digitRangesToText('٠٥٥ ١٢٣', [(3, 5)]), [(4, 6)]);
    });

    test('nothing to map gives nothing', () {
      expect(digitRangesToText('', [(0, 1)]), isEmpty);
      expect(digitRangesToText('123', const []), isEmpty);
    });
  });

  group('hits carry the ranges', () {
    test('the fuzzy digit path', () {
      final idx = FuzzyIndex()
        ..build([Person(name: 'Ann', phones: [const PhoneEntry(number)])]);
      final hit = idx.search('67').single;
      expect(hit.numberRanges, [(8, 10)]);
    });

    test('the pattern path', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init(openStore: false);
      s.replacePeople([
        Person(name: 'Ann', phones: [const PhoneEntry(number)]),
      ]);
      s.setQuery('05*67');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(s.hits.single.numberRanges, [(0, 2), (8, 10)]);
    });
  });
}
