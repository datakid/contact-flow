import 'package:contact_flow/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codes = L.langs.keys.toList();
  final english = L.keysFor('en');
  final token = RegExp(r'\{[a-zA-Z_]+\}');

  for (final code in codes) {
    test('$code has every English string', () {
      final have = L.keysFor(code);
      final missing = english.where((k) => !have.contains(k)).toList();
      expect(missing, isEmpty, reason: '$code is missing ${missing.length}');
    });
  }

  test('placeholders match English in every language', () {
    final base = L('en');
    for (final code in codes) {
      if (code == 'en') continue;
      final l = L(code);
      for (final k in english) {
        final want = token.allMatches(base.t(k)).map((m) => m.group(0)).toSet();
        final got = token.allMatches(l.t(k)).map((m) => m.group(0)).toSet();
        if (code == 'ar' && (k.endsWith('_one') || k.endsWith('One'))) {
          expect(want.containsAll(got), isTrue, reason: '$code $k');
          continue;
        }
        expect(got, want, reason: '$code $k');
      }
    }
  });

  test('no translation is empty', () {
    for (final code in codes) {
      final l = L(code);
      for (final k in english) {
        expect(l.t(k).trim(), isNotEmpty, reason: '$code $k');
      }
    }
  });

  group('Arabic plurals', () {
    const forms = {
      0: 'zero',
      1: 'one',
      2: 'two',
      3: 'few',
      10: 'few',
      11: 'many',
      99: 'many',
      100: 'other',
      101: 'other',
      102: 'other',
      103: 'few',
      110: 'few',
      111: 'many',
      200: 'other',
      1000: 'other',
      1011: 'many',
    };
    forms.forEach((n, form) {
      test('$n is $form', () => expect(L.arabicForm(n), form));
    });

    test('every plural base has all six Arabic forms', () {
      final ar = L('ar');
      for (final base in ['contacts', 'numbers', 'selected']) {
        for (final f in ['zero', 'two', 'few', 'many', 'other']) {
          expect(ar.has('${base}_many_$f'), isTrue, reason: '$base $f');
        }
        expect(ar.has('${base}_one'), isTrue);
      }
    });

    test('few, many and other keep the count; zero, one and two may not', () {
      final ar = L('ar');
      for (final base in ['contacts', 'numbers', 'selected']) {
        for (final f in ['few', 'many', 'other']) {
          expect(ar.t('${base}_many_$f'), contains('{n}'), reason: '$base $f');
        }
      }
    });

    test('n() picks the right form', () {
      final ar = L('ar');
      expect(ar.n(0, 'contacts_one', 'contacts_many'), 'لا توجد جهات اتصال');
      expect(ar.n(1, 'contacts_one', 'contacts_many'), 'جهة اتصال واحدة');
      expect(ar.n(2, 'contacts_one', 'contacts_many'), 'جهتا اتصال');
      expect(ar.n(3, 'contacts_one', 'contacts_many'), '3 جهات اتصال');
      expect(ar.n(11, 'contacts_one', 'contacts_many'), '11 جهة اتصال');
      expect(ar.n(100, 'contacts_one', 'contacts_many'), '100 جهة اتصال');
    });

    test('other languages are unchanged', () {
      final en = L('en');
      expect(en.n(0, 'contacts_one', 'contacts_many'), '0 contacts');
      expect(en.n(1, 'contacts_one', 'contacts_many'), '1 contact');
      expect(en.n(2, 'contacts_one', 'contacts_many'), '2 contacts');
    });
  });
}
