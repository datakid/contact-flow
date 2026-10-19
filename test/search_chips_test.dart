import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/search/number_pattern.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/phone_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<Rig> started(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'lang': 'en', 'theme': 1});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  await t.runAsync(() => rig.book.checkAccess());
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  return rig;
}

Future<void> typeQuery(WidgetTester t, String q) async {
  await t.enterText(find.byKey(const ValueKey('phoneSearch')), q);
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  final en = L('en');

  testWidgets('chips show for a digits-only query and change the mode', (
    t,
  ) async {
    final rig = await started(t);
    await t.pumpWidget(rig.wrap(ContactFlowApp(home: PhoneHome(onTab: (_) {}))));
    await t.pumpAndSettle();

    await typeQuery(t, '055');
    expect(find.text(en.t('digitEnds')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('digit-ends')));
    await t.pump();
    expect(rig.book.digitMode, DigitMode.ends);

    await t.tap(find.byKey(const ValueKey('digit-anywhere')));
    await t.pump();
    expect(rig.book.digitMode, DigitMode.anywhere);
  });

  testWidgets('chips are hidden for a name or a pattern', (t) async {
    final rig = await started(t);
    await t.pumpWidget(rig.wrap(ContactFlowApp(home: PhoneHome(onTab: (_) {}))));
    await t.pumpAndSettle();

    await typeQuery(t, 'ann');
    expect(find.byKey(const ValueKey('digit-ends')), findsNothing);

    await typeQuery(t, '055*');
    expect(find.byKey(const ValueKey('digit-ends')), findsNothing);
  });

  testWidgets('the help sheet explains the syntax', (t) async {
    final rig = await started(t);
    await t.pumpWidget(rig.wrap(ContactFlowApp(home: PhoneHome(onTab: (_) {}))));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('searchHelp')));
    await t.pumpAndSettle();
    expect(find.text(en.t('searchHelpTitle')), findsOneWidget);
    expect(find.textContaining('ends with 36'), findsOneWidget);
  });
}
