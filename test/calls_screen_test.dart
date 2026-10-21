import 'package:contact_flow/calls/call_models.dart';
import 'package:contact_flow/calls/call_source.dart';
import 'package:contact_flow/calls/ignore_book.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/calls_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

CallRecord call(String n, {int daysAgo = 1, int secs = 0}) => CallRecord(
  number: n,
  dateMs: DateTime.now()
      .subtract(Duration(days: daysAgo))
      .millisecondsSinceEpoch,
  durationSec: secs,
);

Future<(Rig, IgnoreBook)> started(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  await t.runAsync(() => rig.book.checkAccess());
  final ignore = IgnoreBook(MemoryTagStore());
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  return (rig, ignore);
}

Widget app(Rig rig, IgnoreBook ignore, CallSource source) => rig.wrap(
  ChangeNotifierProvider<IgnoreBook>.value(
    value: ignore,
    child: ContactFlowApp(
      home: CallsScreen(onTab: (_) {}, source: source),
    ),
  ),
);

void main() {
  final en = L('en');

  final records = [
    call('+966511100001', daysAgo: 1),
    call('+966511100001', daysAgo: 2),
    call('+966511100002', daysAgo: 60, secs: 90),
    call('+966511100003', daysAgo: 3),
  ];

  testWidgets('calls load and the counter starts at zero', (t) async {
    final (rig, ignore) = await started(t);
    await t.pumpWidget(app(rig, ignore, FakeCallSource(records)));
    await t.pumpAndSettle();

    expect(find.textContaining('+966511100001'), findsOneWidget);
    expect(find.textContaining('+966511100003'), findsOneWidget);
    expect(find.text('0 selected · 0 excluded'), findsOneWidget);
    expect(find.byKey(const ValueKey('calls-open-save')), findsNothing);
  });

  testWidgets('tapping a row selects it and shows the save bar', (t) async {
    final (rig, ignore) = await started(t);
    await t.pumpWidget(app(rig, ignore, FakeCallSource(records)));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('+966511100003'));
    await t.pumpAndSettle();
    expect(find.text('1 selected · 0 excluded'), findsOneWidget);
    expect(find.byKey(const ValueKey('calls-open-save')), findsOneWidget);
  });

  testWidgets('a filter chip narrows the list', (t) async {
    final (rig, ignore) = await started(t);
    await t.pumpWidget(app(rig, ignore, FakeCallSource(records)));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('calls-f2')));
    await t.pumpAndSettle();
    expect(find.textContaining('+966511100001'), findsOneWidget);
    expect(find.textContaining('+966511100003'), findsNothing);
  });

  testWidgets('a number pattern narrows the list', (t) async {
    final (rig, ignore) = await started(t);
    await t.pumpWidget(app(rig, ignore, FakeCallSource(records)));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('calls-pattern')), '*003');
    await t.pumpAndSettle();
    expect(find.textContaining('+966511100003'), findsOneWidget);
    expect(find.textContaining('+966511100001'), findsNothing);
  });

  testWidgets('without permission the screen asks and then loads', (t) async {
    final (rig, ignore) = await started(t);
    final source = FakeCallSource(records, granted: false);
    await t.pumpWidget(app(rig, ignore, source));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('calls-allow')), findsOneWidget);
    expect(find.text(en.t('callsAllowBody')), findsOneWidget);

    source.granted = true;
    await t.tap(find.byKey(const ValueKey('calls-allow')));
    await t.pumpAndSettle();
    expect(find.textContaining('+966511100001'), findsOneWidget);
  });

  testWidgets('saving creates the contacts on the phone', (t) async {
    final (rig, ignore) = await started(t);
    await t.pumpWidget(app(rig, ignore, FakeCallSource(records)));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('+966511100003'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('calls-open-save')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('calls-template')), 'Caller {n}');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('calls-save')));
    await t.pumpAndSettle();

    expect(
      rig.book.people.any((p) => p.name == 'Caller 1'),
      isTrue,
    );
    expect(find.textContaining('Saved 1'), findsOneWidget);
  });
}
