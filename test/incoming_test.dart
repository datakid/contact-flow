import 'dart:convert';

import 'package:contact_flow/main.dart';
import 'package:contact_flow/services/incoming.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

IncomingFile vcard() => IncomingFile(
  'shared.vcf',
  bytes: utf8.encode(
    'BEGIN:VCARD\nVERSION:3.0\nFN:Test Person\nTEL:+966501234567\nEND:VCARD\n',
  ),
);

Future<Rig> rigOnTab(WidgetTester t, int tab) async {
  SharedPreferences.setMockInitialValues({'lang': 'en', 'tab': tab});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  return (await t.runAsync(() => makeRig(app: app)))!;
}

void main() {
  setUp(Incoming.reset);
  tearDown(Incoming.reset);

  testWidgets('file shared while the phone tab is open reaches review', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final rig = await rigOnTab(t, 0);
    await t.pumpWidget(rig.wrap(const ContactFlowApp()));
    await t.pumpAndSettle();

    Incoming.deliver([vcard()]);
    await t.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('file shared after visiting Files and returning is not lost', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final rig = await rigOnTab(t, 0);
    await t.pumpWidget(rig.wrap(const ContactFlowApp()));
    await t.pumpAndSettle();

    await t.runAsync(() => rig.app.setTab(1));
    await t.pumpAndSettle();
    await t.runAsync(() => rig.app.setTab(0));
    await t.pumpAndSettle();

    Incoming.deliver([vcard()]);
    await t.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('file delivered before the screen exists is kept', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final rig = await rigOnTab(t, 0);

    Incoming.deliver([vcard()]);
    await t.pumpWidget(rig.wrap(const ContactFlowApp()));
    await t.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('unreadable shared file shows a message, not review', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final rig = await rigOnTab(t, 0);
    await t.pumpWidget(rig.wrap(const ContactFlowApp()));
    await t.pumpAndSettle();

    Incoming.deliver([const IncomingFile('big.csv', error: 'tooLarge')]);
    await t.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
