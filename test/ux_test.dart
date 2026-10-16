import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('skipped rows', () {
    test('rows without a phone or email are counted', () {
      final r = Codec.decode(
        'c.csv',
        text(
          'Name,Phone\n'
          'Ali,+201001234567\n'
          'NoPhone,\n'
          'Sara,+201001234568\n'
          'AlsoNone,\n',
        ),
      );
      expect(r.people.length, 2);
      expect(r.skipped, 2);
    });

    test('a complete file skips nothing', () {
      final r = Codec.decode(
        'c.csv',
        text('Name,Phone\nAli,+201001234567\nSara,+201001234568\n'),
      );
      expect(r.people.length, 2);
      expect(r.skipped, 0);
    });

    test('the plan adds skipped rows across files', () async {
      SharedPreferences.setMockInitialValues({'lang': 'en'});
      final s = AppState();
      await s.init();
      Person one(String n, String phone) =>
          Person(name: n, phones: [PhoneEntry(phone)], source: 'x.csv');
      final plan = s.plan([
        ImportResult([one('A', '+201001234567')], Format.csv, '', skipped: 2),
        ImportResult([one('B', '+201001234568')], Format.csv, '', skipped: 3),
        ImportResult.failed('broken.xlsx'),
      ]);
      expect(plan.skipped, 5);
      expect(plan.incoming.length, 2);
    });
  });

  group('accessibility', () {
    testWidgets('FadeSlideIn is instant when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FadeSlideIn(child: Text('hello')),
          ),
        ),
      );
      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('FadeSlideIn still animates by default', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FadeSlideIn(child: Text('hello')),
          ),
        ),
      );
      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 0.0);
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('Pressable exposes a labelled tap target', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Pressable(
              semanticLabel: 'Delete',
              onTap: () => taps++,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(Pressable));
      expect(node.label, 'Delete');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.byType(Pressable));
      expect(taps, 1);
      handle.dispose();
    });
  });
}
