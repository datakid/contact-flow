import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<Rig> open(WidgetTester t, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues({
    'lang': 'en',
    'tab': 0,
    'country': '+44',
    ...prefs,
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
      tags: TagBook(MemoryTagStore()),
      child: const ContactFlowApp(),
    ),
  );
  await t.pumpAndSettle();
  return rig;
}

Future<void> swipe(WidgetTester t, double dx) async {
  await t.fling(find.byType(SwipeActions).first, Offset(dx, 0), 1500);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('from the start edge calls, from the end edge messages', (
    t,
  ) async {
    final rig = await open(t, {});
    await swipe(t, 500);
    expect(rig.launcher.opened.map((u) => u.scheme), ['tel']);
    await swipe(t, -500);
    expect(rig.launcher.opened.map((u) => u.scheme), ['tel', 'smsto']);
    expect(find.byType(SwipeActions), findsWidgets);
  });

  testWidgets('in Arabic the gestures flip with the reading direction', (
    t,
  ) async {
    final rig = await open(t, {'lang': 'ar'});
    await swipe(t, -500);
    expect(rig.launcher.opened.map((u) => u.scheme), ['tel']);
    await swipe(t, 500);
    expect(rig.launcher.opened.map((u) => u.scheme), ['tel', 'smsto']);
  });

  testWidgets('turned off, rows do not swipe', (t) async {
    final rig = await open(t, {'swipeActions': false});
    expect(find.byType(Dismissible), findsNothing);
    await t.fling(find.text('Amelia Hart').first, const Offset(500, 0), 1500);
    await t.pumpAndSettle();
    expect(rig.launcher.opened, isEmpty);
  });

  testWidgets('the setting is remembered', (t) async {
    final app = (await t.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init(openStore: false);
      await s.setSwipeActions(false);
      final again = AppState();
      await again.init(openStore: false);
      return again;
    }))!;
    expect(app.swipeActions, isFalse);
  });
}
