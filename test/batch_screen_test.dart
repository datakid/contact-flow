import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/jobs.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/batch_screen.dart';
import 'package:contact_flow/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget host(AppState s, List<Person> people) => ChangeNotifierProvider.value(
  value: s,
  child: LScope(
    l: L('en'),
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => openBatchEditor(c, people),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'export encodes in a background isolate (share/save crash fix)',
    () async {
      final people = List.generate(
        600,
        (i) =>
            Person(name: 'P$i', phones: [PhoneEntry('+97150${1000000 + i}')]),
      );
      for (final f in Format.values) {
        final bytes = await compute(
          runEncode,
          EncodeJob(people, f, const ExportOptions(), null),
        );
        expect(bytes, isNotEmpty);
        final back = await compute(
          runDecode,
          DecodeJob('x.${f.exportExt}', bytes),
        );
        expect(back.people.length, 600, reason: f.name);
      }
      final viaHelper = await encodeInBackground(
        EncodeJob(people, Format.csv, const ExportOptions(), null),
      );
      expect(viaHelper, isNotEmpty);
    },
  );

  testWidgets('batch table: edit a cell, run an operation, save', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);

    final s = AppState();
    final a = Person(name: 'ali hassan', phones: [PhoneEntry('050 111 2222')]);
    final b = Person(name: 'Bob', phones: [PhoneEntry('052 333 4444')]);
    await s.commit(ImportPlan([a, b], [a, b], const [], const [], const {}));
    final people = s.people;
    expect(people.length, 2);
    final bob = people.firstWhere((p) => p.name == 'Bob');

    await t.pumpWidget(host(s, people));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Batch edit'), findsOneWidget);

    await t.tap(find.text('Bob'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Robert');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Robert'), findsOneWidget);
    expect(find.text('1 changed'), findsOneWidget);

    await t.tap(find.text('Operations'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Add country code'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('Add country code'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '+971');
    await t.pumpAndSettle();
    expect(find.text('Apply to 2'), findsOneWidget);
    await t.tap(find.text('Apply to 2'));
    await t.pumpAndSettle();
    expect(find.text('+971501112222'), findsOneWidget);
    expect(find.text('+971523334444'), findsOneWidget);

    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(find.text('050 111 2222'), findsOneWidget);
    expect(find.text('Robert'), findsOneWidget);

    await t.tap(find.text('Save 1 change'));
    await t.pumpAndSettle();
    expect(find.text('Batch edit'), findsNothing);
    expect(s.people.map((p) => p.name).toSet(), {'ali hassan', 'Robert'});
    expect(bob.name, 'Bob');
    expect(s.byId(bob.id)?.name, 'Robert');
  });
}
