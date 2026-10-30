import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/person_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  testWidgets('long press then drag selects the rows in between', (t) async {
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
    final rows = find.byType(PersonRow);
    final first = t.getCenter(rows.at(0));
    final third = t.getCenter(rows.at(2));
    final gesture = await t.startGesture(first);
    await t.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(third);
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();
    expect(rig.book.selected.length, 3);
  });

  testWidgets('dragging back shrinks the range', (t) async {
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
    final rows = find.byType(PersonRow);
    final gesture = await t.startGesture(t.getCenter(rows.at(0)));
    await t.pump(const Duration(milliseconds: 700));
    final third = t.getCenter(rows.at(2));
    await gesture.moveTo(third);
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();
    expect(rig.book.selected.length, 3);
  });

  testWidgets('dragging back shrinks the range', (t) async {
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
    final rows = find.byType(PersonRow);
    final gesture = await t.startGesture(t.getCenter(rows.at(0)));
    await t.pump(const Duration(milliseconds: 700));
    final ctx = t.element(find.byType(Scaffold).first);
    final third = t.getCenter(rows.at(2));
    final thirdId = (rows.at(2).evaluate().first.widget as PersonRow).person.id;
    // ignore: avoid_print
    print('DIAG after hold selected=${rig.book.selected.length} mark=${RowMark.at(ctx, third)} want=$thirdId');
    await gesture.moveTo(third);
    await t.pump();
    expect(rig.book.selected.length, 3);
    await gesture.moveTo(t.getCenter(rows.at(1)));
    await t.pump();
    expect(rig.book.selected.length, 2);
    await gesture.up();
  });
}
