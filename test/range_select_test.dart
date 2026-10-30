import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/person_row.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<Rig> open(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'lang': 'en',
    'tab': 0,
    'swipeActions': false,
  });
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  await t.runAsync(() => rig.book.checkAccess());
  await t.pumpWidget(
    AppProviders(
      state: rig.app,
      book: rig.book,
      queue: rig.queue,
      launcher: rig.launcher,
      child: const ContactFlowApp(),
    ),
  );
  await t.pumpAndSettle();
  return rig;
}

void main() {
  testWidgets('long press then drag selects the rows in between', (t) async {
    final rig = await open(t);
    final rows = find.byType(PersonRow);
    final gesture = await t.startGesture(t.getCenter(rows.at(0)));
    await t.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(t.getCenter(rows.at(2)));
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();
    expect(rig.book.selected.length, 3);
  });

  testWidgets('dragging back shrinks the range', (t) async {
    final rig = await open(t);
    final rows = find.byType(PersonRow);
    final gesture = await t.startGesture(t.getCenter(rows.at(0)));
    await t.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(t.getCenter(rows.at(2)));
    await t.pump();
    expect(rig.book.selected.length, 3);
    await gesture.moveTo(t.getCenter(rows.at(1)));
    await t.pump();
    expect(rig.book.selected.length, 2);
    await gesture.up();
  });

  testWidgets('a range adds to what was already selected', (t) async {
    final rig = await open(t);
    final rows = find.byType(PersonRow);
    final first = await t.startGesture(t.getCenter(rows.at(1)));
    await t.pump(const Duration(milliseconds: 700));
    await first.up();
    await t.pump();
    await t.pumpAndSettle();
    expect(rig.book.selected.length, 1);
    final gesture = await t.startGesture(t.getCenter(rows.at(0)));
    await t.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await t.pumpAndSettle();
    expect(rig.book.selected.length, 2);
  });
}
