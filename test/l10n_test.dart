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
        if (code == 'ar' && (k.endsWith('_one') || k.endsWith('One'))) continue;
        final want = token.allMatches(base.t(k)).map((m) => m.group(0)).toSet();
        final got = token.allMatches(l.t(k)).map((m) => m.group(0)).toSet();
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
}
