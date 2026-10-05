import 'package:contact_flow/data/sample.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/main.dart' as app;
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_flow/data/contact_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<AppState> seeded(String lang) async {
  SharedPreferences.setMockInitialValues({'lang': lang});
  final s = AppState();
  await s.init();
  await s.commit(s.plan([ImportResult(Sample.people(), Format.vcf, 'sample')]));
  return s;
}

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('home → search → batch editor ($lang)', (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final s = (await t.runAsync(() => seeded(lang)))!;
      expect(s.people, isNotEmpty);
      final rig = (await t.runAsync(
        () => makeRig(app: s, access: Access.unsupported),
      ))!;

      await t.pumpWidget(rig.wrap(const ContactFlowApp()));
      await t.pumpAndSettle();

      // Tap the far edge of the search pill (not the text line) — should focus.
      final field = find.byType(TextField).first;
      final rect = t.getRect(field);
      await t.tapAt(Offset(rect.center.dx, rect.top + 2));
      await t.pump();
      final editable = t.widget<TextField>(field);
      expect(editable.focusNode!.hasFocus, isTrue);

      final first = s.people.first.displayName.split(' ').first;
      await t.enterText(field, first);
      await t.pump(const Duration(milliseconds: 300));
      expect(s.searching, isTrue);
      expect(s.visible, isNotEmpty);

      // Batch editor on the search results.
      await t.tap(find.byIcon(Icons.table_rows_outlined).first);
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      await t.tap(find.byIcon(Icons.auto_fix_high_rounded));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.find_replace_rounded), findsOneWidget);
    });
  }

  testWidgets('settings shows version and font licenses', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = (await t.runAsync(() => seeded('en')))!;
    app.registerFontLicenses();
    final rig = (await t.runAsync(
      () => makeRig(app: s, access: Access.unsupported),
    ))!;
    await t.pumpWidget(rig.wrap(const ContactFlowApp()));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.tune_rounded));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Open-source licenses'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Contact Flow 2.1.0 · MIT'), findsOneWidget);
    final entries = await t.runAsync(() => LicenseRegistry.licenses.toList());
    final pkgs = entries!.expand((e) => e.packages).toSet();
    expect(pkgs, containsAll(['Manrope', 'Instrument Serif']));
  });
}
