import 'package:contact_flow/search/number_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

NumberAtom N(String p, {bool plus = false}) => NumberAtom(p, plus: plus);
TagAtom T(String t) => TagAtom(t);
TextAtom X(String t) => TextAtom(t);

void parses(String query, List<List<QueryAtom>> expected) {
  test('parses "$query"', () {
    expect(NumberQuery.parse(query).alternatives, expected);
  });
}

PhoneForms forms(String saved, String national, String e164) =>
    PhoneForms(saved, saved, national, e164);

final sa = forms('0551234567', '0551234567', '966551234567');
final saIntl = forms('966551234567', '0551234567', '966551234567');
final other = forms('0212345636', '0212345636', '966212345636');

int? score(
  String q,
  List<PhoneForms> numbers, {
  DigitMode mode = DigitMode.anywhere,
  Set<String> tags = const {},
}) => NumberQuery.parse(q, mode: mode).score(numbers, hasTag: tags.contains);

void main() {
  group('parser', () {
    parses('36', [[N('36')]]);
    parses('٣٦', [[N('36')]]);
    parses('３６', [[N('36')]]);
    parses('۳۶', [[N('36')]]);
    parses('*36', [[N('*36')]]);
    parses('02*', [[N('02*')]]);
    parses('02*36', [[N('02*36')]]);
    parses('*55*', [[N('*55*')]]);
    parses('**36', [[N('*36')]]);
    parses('*36*', [[N('*36*')]]);
    parses('05?1*', [[N('05?1*')]]);
    parses('٠٥؟١*', [[N('05?1*')]]);
    parses('０５？１＊', [[N('05?1*')]]);
    parses('02* #work', [[N('02*'), T('work')]]);
    parses('02*＃work', [[N('02*'), T('work')]]);
    parses('02*#work', [[N('02*'), T('work')]]);
    parses('*36, *37', [[N('*36')], [N('*37')]]);
    parses('*36،*37', [[N('*36')], [N('*37')]]);
    parses('*36，*37', [[N('*36')], [N('*37')]]);
    parses('*36 , *37 , *38', [[N('*36')], [N('*37')], [N('*38')]]);
    parses('055 123 4567', [[N('0551234567')]]);
    parses('(055) 123-4567', [[N('0551234567')]]);
    parses('055-123-4567', [[N('0551234567')]]);
    parses('+966*', [[N('966*', plus: true)]]);
    parses('+966 55', [[N('96655', plus: true)]]);
    parses('*', [[N('*')]]);
    parses('', const <List<QueryAtom>>[]);
    parses('   ', const <List<QueryAtom>>[]);
    parses(',', const <List<QueryAtom>>[]);
    parses('ahmed', [[X('ahmed')]]);
    parses('ahmed, 36', [[X('ahmed 36')]]);
    parses('#work', [[T('work')]]);
    parses('#', const <List<QueryAtom>>[]);
    parses('#Work', [[T('work')]]);
    parses('*36 *37', [[N('*36'), N('*37')]]);
    parses('#a #b', [[T('a'), T('b')]]);
    parses('?', [[N('?')]]);
    parses('05??', [[N('05??')]]);
    parses('ahmed 36', [[X('ahmed'), N('36')]]);
    parses('36 ahmed', [[N('36'), X('ahmed')]]);
    parses('*٣٦', [[N('*36')]]);
    parses('٠٥٥ ١٢٣', [[N('055123')]]);
    parses('+٩٦٦*', [[N('966*', plus: true)]]);
    parses('02*, #work', [[N('02*')], [T('work')]]);
    parses('*36,', [[N('*36')]]);
    parses(',*36', [[N('*36')]]);
    parses('036', [[N('036')]]);
    parses('1,2', [[N('1')], [N('2')]]);
  });

  group('query shape', () {
    test('empty and blank queries are empty', () {
      expect(NumberQuery.parse('').isEmpty, isTrue);
      expect(NumberQuery.parse('  ').isEmpty, isTrue);
    });

    test('digit-only queries are flagged', () {
      expect(NumberQuery.parse('36').digitsOnly, isTrue);
      expect(NumberQuery.parse('*36').digitsOnly, isFalse);
      expect(NumberQuery.parse('055 123 4567').digitsOnly, isTrue);
      expect(NumberQuery.parse('*36 *37').digitsOnly, isFalse);
    });

    test('pattern, tag and text queries are told apart', () {
      expect(NumberQuery.parse('*36').isPattern, isTrue);
      expect(NumberQuery.parse('#work').isPattern, isTrue);
      expect(NumberQuery.parse('ahmed').isPattern, isFalse);
      expect(NumberQuery.parse('ahmed *36').hasNumberAtoms, isTrue);
    });

    test('the text part of a mixed query is kept for the name search', () {
      expect(NumberQuery.parse('ahmed *36').text, 'ahmed');
      expect(NumberQuery.parse('ahmed').text, 'ahmed');
    });

    test('normalizeChars maps Arabic, Persian and full-width characters', () {
      expect(NumberQuery.normalizeChars('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(NumberQuery.normalizeChars('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(NumberQuery.normalizeChars('０１２３'), '0123');
      expect(NumberQuery.normalizeChars('؟،＊＃，？'), '?,*#,?');
    });
  });

  group('matching a single number', () {
    test('plain digits are ranked exact, ends, starts, contains', () {
      expect(score('0551234567', [sa]), 4);
      expect(score('4567', [sa]), 3);
      expect(score('055', [sa]), 2);
      expect(score('123', [sa]), 1);
      expect(score('999', [sa]), isNull);
    });

    test('chips restrict plain digits to one kind of match', () {
      expect(score('67', [sa], mode: DigitMode.ends), 3);
      expect(score('67', [sa], mode: DigitMode.starts), isNull);
      expect(score('67', [sa], mode: DigitMode.contains), 1);
      expect(score('055', [sa], mode: DigitMode.starts), 2);
      expect(score('055', [sa], mode: DigitMode.ends), isNull);
      expect(score('55', [sa], mode: DigitMode.contains), 1);
    });

    test('star at the front means ends with', () {
      expect(score('*67', [sa]), 3);
      expect(score('*66', [sa]), isNull);
    });

    test('star at the back means starts with', () {
      expect(score('055*', [sa]), 3);
      expect(score('056*', [sa]), isNull);
    });

    test('stars at both ends mean contains', () {
      expect(score('*55*', [sa]), 3);
      expect(score('*99*', [sa]), isNull);
    });

    test('a star in the middle means starts with and ends with', () {
      expect(score('02*36', [other]), 3);
      expect(score('02*37', [other]), isNull);
    });

    test('question mark is exactly one digit', () {
      expect(score('05?1*', [sa]), 3);
      expect(score('05?2*', [sa]), isNull);
      expect(score('055123456?', [sa]), 3);
      expect(score('05512345?', [sa]), isNull);
    });

    test('a lone star matches any number', () {
      expect(score('*', [sa]), 3);
      expect(score('*', const []), isNull);
    });

    test('starts with is checked against the national and E.164 forms', () {
      expect(score('05*', [saIntl]), 3);
      expect(score('9665*', [sa]), 3);
      expect(score('96655*', [sa]), 3);
    });

    test('a leading plus only looks at the E.164 form', () {
      expect(score('+966*', [sa]), 3);
      expect(score('+055*', [sa]), isNull);
    });

    test('Arabic and full-width queries match the same numbers', () {
      expect(score('٠٥٥*', [sa]), 3);
      expect(score('０５５＊', [sa]), 3);
      expect(score('*٦٧', [sa]), 3);
      expect(score('٠٥؟١*', [sa]), 3);
    });

    test('numbers without a country code still match by saved digits', () {
      final plain = forms('5551234', '', '');
      expect(score('*234', [plain]), 3);
      expect(score('55*', [plain]), 3);
    });
  });

  group('and, or and tags', () {
    test('space is AND on the same number', () {
      expect(score('055* *67', [sa]), 6);
      expect(score('055* *66', [sa]), isNull);
    });

    test('AND does not combine two different numbers', () {
      expect(score('055* *36', [sa, other]), isNull);
      expect(score('02* *36', [sa, other]), 6);
    });

    test('comma is OR', () {
      expect(score('*36, *67', [sa]), 3);
      expect(score('*36, *37', [sa]), isNull);
      expect(score('*36، *67', [sa]), 3);
    });

    test('best score wins across alternatives and numbers', () {
      expect(score('*55*, 0551234567', [sa]), 4);
      expect(score('*67', [sa, other]), 3);
      expect(score('02*', [sa, other]), 3);
    });

    test('a tag is required when the query names one', () {
      expect(score('02* #work', [other]), isNull);
      expect(score('02* #work', [other], tags: {'work'}), 4);
      expect(score('02* #work', [other], tags: {'home'}), isNull);
    });

    test('a tag alone matches without any number', () {
      expect(score('#work', const [], tags: {'work'}), 1);
      expect(score('#work', const [], tags: {'home'}), isNull);
    });

    test('text-only queries have no number score', () {
      expect(score('ahmed', [sa]), isNull);
    });
  });

  group('highlights', () {
    test('plain digits highlight where they matched', () {
      final q = NumberQuery.parse('67');
      final a = q.alternatives.first.first as NumberAtom;
      expect(q.highlights(a, '0551234567'), [(8, 10)]);
    });

    test('contains highlights the first occurrence', () {
      final q = NumberQuery.parse('55');
      final a = q.alternatives.first.first as NumberAtom;
      expect(q.highlights(a, '0551234567'), [(1, 3)]);
    });

    test('a glob highlights each literal segment', () {
      final q = NumberQuery.parse('05*67');
      final a = q.alternatives.first.first as NumberAtom;
      expect(q.highlights(a, '0551234567'), [(0, 2), (8, 10)]);
    });

    test('question marks count as positions', () {
      final q = NumberQuery.parse('05?1*');
      final a = q.alternatives.first.first as NumberAtom;
      expect(q.highlights(a, '0551234567'), [(0, 4)]);
    });

    test('no match gives no ranges', () {
      final q = NumberQuery.parse('*99');
      final a = q.alternatives.first.first as NumberAtom;
      expect(q.highlights(a, '0551234567'), isEmpty);
    });
  });

  group('phone forms', () {
    test('extensions are not part of the digits', () {
      final f = PhoneForms.of('0551234567 x12');
      expect(f.saved, '0551234567');
    });

    test('Arabic-Indic digits become ASCII', () {
      expect(PhoneForms.of('٠٥٥١٢٣٤٥٦٧').saved, '0551234567');
    });

    test('all lists each distinct form once', () {
      final f = PhoneForms('x', '0551234567', '0551234567', '966551234567');
      expect(f.all.toList(), ['0551234567', '966551234567']);
    });
  });
}
