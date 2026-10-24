import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/search_extras.dart';
import 'package:contact_flow/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<(Widget, AppState, TagBook)> host(WidgetTester t, {bool tags = true}) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  final book = TagBook(MemoryTagStore());
  await t.runAsync(book.load);
  if (tags) {
    await t.runAsync(() => book.create('VIP'));
    await t.runAsync(() => book.create('Work'));
  }
  return (
    AppProviders(
      state: rig.app,
      book: rig.book,
      queue: rig.queue,
      launcher: rig.launcher,
      tags: book,
      child: ContactFlowApp(
        home: Scaffold(body: TagFilterRow(list: rig.app)),
      ),
    ),
    app,
    book,
  );
}

void main() {
  testWidgets('one pill per tag, tapping sets and clears the filter', (t) async {
    final (w, app, _) = await host(t);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tagfilter-VIP')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagfilter-Work')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('tagfilter-VIP')));
    await t.pumpAndSettle();
    expect(app.tagFilter, 'VIP');

    await t.tap(find.byKey(const ValueKey('tagfilter-VIP')));
    await t.pumpAndSettle();
    expect(app.tagFilter, isNull);
  });

  testWidgets('nothing is drawn when there are no tags', (t) async {
    final (w, _, _) = await host(t, tags: false);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    expect(find.byType(Pill), findsNothing);
  });
}
