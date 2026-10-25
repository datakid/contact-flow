import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

class ThrowingState extends AppState {
  @override
  Future<int> commit(ImportPlan plan, {bool merge = true}) async =>
      throw StateError('disk full');
}

Person person(String name, String number) =>
    Person(name: name, phones: [PhoneEntry(number)]);

ImportPlan planOf(
  List<Person> fresh, {
  List<(Person, Person)> dupes = const [],
}) => ImportPlan(
  [...fresh, ...dupes.map((d) => d.$1)],
  fresh,
  dupes,
  const ['x.csv'],
  {Format.csv: fresh.length + dupes.length},
);

Future<Rig> rigFor(WidgetTester t, AppState app) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  await t.runAsync(() => app.init(openStore: false));
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  return (await t.runAsync(() => makeRig(app: app)))!;
}

void main() {
  final en = L('en');

  testWidgets('skipped duplicates do not change the count after merge is toggled', (
    t,
  ) async {
    final rig = await rigFor(t, AppState());
    final fresh = [person('Ann', '0551111111'), person('Bob', '0552222222')];
    final dupes = [
      (person('Cy', '0553333333'), person('Cy', '0553333333')),
      (person('Di', '0554444444'), person('Di', '0554444444')),
    ];
    await t.pumpWidget(
      rig.wrap(
        ContactFlowApp(home: ReviewScreen(plan: planOf(fresh, dupes: dupes))),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 2})), findsOneWidget);

    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 4})), findsOneWidget);

    await t.tap(find.text('Cy'));
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 3})), findsOneWidget);

    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 2})), findsOneWidget);
  });

  testWidgets('a row past 400 can be skipped', (t) async {
    final rig = await rigFor(t, AppState());
    final fresh = [
      for (var i = 0; i < 450; i++)
        person('P${i.toString().padLeft(3, '0')}', '055${i.toString().padLeft(7, '0')}'),
    ];
    await t.pumpWidget(
      rig.wrap(ContactFlowApp(home: ReviewScreen(plan: planOf(fresh)))),
    );
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 450})), findsOneWidget);

    await t.scrollUntilVisible(
      find.text('P449'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('P449'));
    await t.pumpAndSettle();
    expect(find.text(en.t('addN', {'n': 449})), findsOneWidget);
  });

  testWidgets('a failed save stops the spinner and shows a message', (t) async {
    final rig = await rigFor(t, ThrowingState());
    final fresh = [person('Ann', '0551111111')];
    await t.pumpWidget(
      rig.wrap(ContactFlowApp(home: ReviewScreen(plan: planOf(fresh)))),
    );
    await t.pumpAndSettle();

    await t.tap(find.text(en.t('addN', {'n': 1})));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(en.t('importFailed')), findsOneWidget);
    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('labels become tags on numbers when the switch is on', (t) async {
    final rig = await rigFor(t, AppState());
    final book = TagBook(MemoryTagStore());
    await t.runAsync(book.load);
    final ann = Person(
      name: 'Ann',
      phones: [const PhoneEntry('+966511100001')],
      groups: ['Family'],
    );
    await t.pumpWidget(
      AppProviders(
        state: rig.app,
        book: rig.book,
        queue: rig.queue,
        launcher: rig.launcher,
        tags: book,
        child: ContactFlowApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                key: const ValueKey('go'),
                onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<int>(
                    builder: (_) => ReviewScreen(plan: planOf([ann])),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('go')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('labels-to-tags')), findsOneWidget);

    await t.tap(find.text(en.t('addN', {'n': 1})));
    await t.pumpAndSettle();
    expect(book.byName('Family'), isNotNull);
    expect(book.tagsForNumber('+966511100001').single.name, 'Family');
  });

  testWidgets('turning the switch off creates no tags', (t) async {
    final rig = await rigFor(t, AppState());
    final book = TagBook(MemoryTagStore());
    await t.runAsync(book.load);
    final ann = Person(
      name: 'Ann',
      phones: [const PhoneEntry('+966511100001')],
      groups: ['Family'],
    );
    await t.pumpWidget(
      AppProviders(
        state: rig.app,
        book: rig.book,
        queue: rig.queue,
        launcher: rig.launcher,
        tags: book,
        child: ContactFlowApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                key: const ValueKey('go'),
                onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<int>(
                    builder: (_) => ReviewScreen(plan: planOf([ann])),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('go')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('labels-to-tags')));
    await t.pumpAndSettle();
    await t.tap(find.text(en.t('addN', {'n': 1})));
    await t.pumpAndSettle();
    expect(book.tags, isEmpty);
  });
}
