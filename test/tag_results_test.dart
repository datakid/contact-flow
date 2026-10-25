import 'package:contact_flow/main.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/search_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<(Widget, AppState, TagBook)> host(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  final book = TagBook(MemoryTagStore());
  await t.runAsync(book.load);
  app.replacePeople([
    Person(name: 'Ann', phones: [const PhoneEntry('0551234536')]),
    Person(name: 'Bob', phones: [const PhoneEntry('0559876543')]),
    Person(name: 'Cy', phones: [const PhoneEntry('0212345636')]),
  ]);
  return (
    AppProviders(
      state: rig.app,
      book: rig.book,
      queue: rig.queue,
      launcher: rig.launcher,
      tags: book,
      child: ContactFlowApp(
        home: Scaffold(body: TagResultsButton(list: rig.app)),
      ),
    ),
    app,
    book,
  );
}

void main() {
  testWidgets('the button appears for a number pattern and tags every match', (
    t,
  ) async {
    final (w, app, book) = await host(t);
    await t.pumpWidget(w);
    expect(find.byKey(const ValueKey('tag-results')), findsNothing);

    app.setQuery('*36');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Tag 2 numbers…'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('tag-results')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pick-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('tag-name')), 'Batch');
    await t.tap(find.byKey(const ValueKey('tag-name-ok')));
    await t.pumpAndSettle();

    final tag = book.byName('Batch')!;
    expect(book.count(tag.id), 2);
    expect(book.tagsForNumber('0551234536').single.name, 'Batch');
    expect(book.tagsForNumber('0212345636').single.name, 'Batch');
    expect(book.tagsForNumber('0559876543'), isEmpty);
    expect(find.text('Tagged 2 numbers'), findsOneWidget);
  });

  testWidgets('no button for a plain name search', (t) async {
    final (w, app, _) = await host(t);
    await t.pumpWidget(w);
    app.setQuery('ann');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('tag-results')), findsNothing);
  });
}
