import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/tags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<(Widget, TagBook)> host(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  final book = TagBook(MemoryTagStore());
  await t.runAsync(book.load);
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  return (
    AppProviders(
      state: rig.app,
      book: rig.book,
      queue: rig.queue,
      launcher: rig.launcher,
      tags: book,
      child: const ContactFlowApp(home: TagsScreen()),
    ),
    book,
  );
}

Future<void> typeName(WidgetTester t, String name) async {
  await t.enterText(find.byKey(const ValueKey('tag-name')), name);
  await t.tap(find.byKey(const ValueKey('tag-name-ok')));
  await t.pumpAndSettle();
}

void main() {
  final en = L('en');

  testWidgets('an empty book explains tags', (t) async {
    final (w, _) = await host(t);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tags-empty')), findsOneWidget);
  });

  testWidgets('a tag can be created and appears with its count', (t) async {
    final (w, book) = await host(t);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tag-new')));
    await t.pumpAndSettle();
    await typeName(t, 'Work');
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('0 numbers'), findsOneWidget);
    expect(book.tags.single.name, 'Work');
  });

  testWidgets('rename refuses a duplicate name', (t) async {
    final (w, book) = await host(t);
    final a = await t.runAsync(() => book.create('Work'));
    await t.runAsync(() => book.create('Home'));
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    final home = book.byName('Home')!;
    await t.tap(find.byKey(ValueKey('tag-menu-${home.id}')));
    await t.pumpAndSettle();
    await t.tap(find.text(en.t('tagRename')));
    await t.pumpAndSettle();
    await typeName(t, 'work');
    expect(find.text(en.t('tagExists')), findsOneWidget);
    expect(book.byId(home.id)!.name, 'Home');
    expect(book.byId(a!.id)!.name, 'Work');
  });

  testWidgets('delete can be undone', (t) async {
    final (w, book) = await host(t);
    final tag = (await t.runAsync(() => book.create('Work')))!;
    await t.runAsync(() => book.assign([tag.id], ['+966501234567']));
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('tag-menu-${tag.id}')));
    await t.pumpAndSettle();
    await t.tap(find.text(en.t('tagDelete')));
    await t.pumpAndSettle();
    expect(book.tags, isEmpty);
    await t.tap(find.text(en.t('undo')));
    await t.pumpAndSettle();
    expect(book.tags.single.name, 'Work');
    expect(book.count(tag.id), 1);
  });

  testWidgets('merge moves the numbers into the chosen tag', (t) async {
    final (w, book) = await host(t);
    final a = (await t.runAsync(() => book.create('A')))!;
    final b = (await t.runAsync(() => book.create('B')))!;
    await t.runAsync(() => book.assign([a.id], ['+966501234567']));
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('tag-menu-${a.id}')));
    await t.pumpAndSettle();
    await t.tap(find.text(en.t('tagMerge')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('tag-merge-${b.id}')));
    await t.pumpAndSettle();
    expect(book.byId(a.id), isNull);
    expect(book.count(b.id), 1);
  });
}
