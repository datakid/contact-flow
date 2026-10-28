import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/phone_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<(Widget, TagBook, String, String)> host(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  await t.runAsync(() => rig.book.checkAccess());
  final book = TagBook(MemoryTagStore());
  await t.runAsync(book.load);
  final person = rig.book.people.firstWhere((p) => p.phones.isNotEmpty);
  t.view.physicalSize = const Size(1080, 2600);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  return (
    AppProviders(
      state: rig.app,
      book: rig.book,
      queue: rig.queue,
      launcher: rig.launcher,
      tags: book,
      child: ContactFlowApp(home: PhoneDetailScreen(id: person.id)),
    ),
    book,
    person.id,
    person.phones.first.number,
  );
}

void main() {
  final en = L('en');

  testWidgets('a new tag can be created and put on a number', (t) async {
    final (w, book, _, number) = await host(t);
    await t.pumpWidget(w);
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.byKey(ValueKey('numtag-add-$number')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(ValueKey('numtag-add-$number')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pick-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('tag-name')), 'Work');
    await t.tap(find.byKey(const ValueKey('tag-name-ok')));
    await t.pumpAndSettle();

    expect(book.tagsForNumber(number).single.name, 'Work');
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('an existing tag can be picked and removed again', (t) async {
    final (w, book, _, number) = await host(t);
    final tag = (await t.runAsync(() => book.create('Home')))!;
    await t.pumpWidget(w);
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.byKey(ValueKey('numtag-add-$number')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(ValueKey('numtag-add-$number')));
    await t.pumpAndSettle();
    expect(find.text(en.t('tagPickTitle')), findsOneWidget);
    await t.tap(find.byKey(ValueKey('pick-${tag.id}')));
    await t.pumpAndSettle();
    expect(book.tagIdsForNumber(number), {tag.id});

    await t.tap(
      find
          .descendant(
            of: find.byKey(ValueKey('numtag-$number-${tag.id}')),
            matching: find.byType(Icon),
          )
          .last,
    );
    await t.pumpAndSettle();
    expect(book.tagIdsForNumber(number), isEmpty);
  });

  testWidgets('without a tag book the card is not shown', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'en'});
    final app = AppState();
    await t.runAsync(() => app.init(openStore: false));
    final rig = (await t.runAsync(() => makeRig(app: app)))!;
    await t.runAsync(() => rig.book.checkAccess());
    final person = rig.book.people.firstWhere((p) => p.phones.isNotEmpty);
    await t.pumpWidget(
      rig.wrap(ContactFlowApp(home: PhoneDetailScreen(id: person.id))),
    );
    await t.pumpAndSettle();
    expect(find.text(en.t('tagAdd')), findsNothing);
  });
}
