import 'package:contact_flow/data/contact_source.dart';
import 'package:contact_flow/domain/planner.dart';
import 'package:contact_flow/domain/reach.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/compose_screen.dart';
import 'package:contact_flow/ui/history_screen.dart';
import 'package:contact_flow/ui/merge_screen.dart';
import 'package:contact_flow/ui/phone_detail.dart';
import 'package:contact_flow/ui/phone_edit.dart';
import 'package:contact_flow/ui/phone_home.dart';
import 'package:contact_flow/ui/person_row.dart';
import 'package:contact_flow/ui/pipeline.dart';
import 'package:contact_flow/ui/queue_screen.dart';
import 'package:contact_flow/ui/settings_sheet.dart';
import 'package:contact_flow/ui/sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<Rig> rigFor(
  WidgetTester t,
  String lang, {
  bool dark = false,
  Access access = Access.granted,
}) async {
  SharedPreferences.setMockInitialValues({
    'lang': lang,
    'theme': dark ? 2 : 1,
    'country': '+44',
  });
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app, access: access)))!;
  rig.book.sortLang = lang;
  await t.runAsync(() => rig.book.checkAccess());
  return rig;
}

void small(WidgetTester t) {
  trackOverflows();
  t.view.physicalSize = const Size(360 * 3, 760 * 3);
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

final overflowLog = <String>[];

void trackOverflows() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final w =
        d.informationCollector?.call().map((e) => e.toString()).join(' | ') ??
        '';
    overflowLog.add(
      '${d.exceptionAsString()} @ ${w.length > 600 ? w.substring(0, 600) : w}',
    );
    prev?.call(d);
  };
}

Future<void> show(WidgetTester t, Rig rig, Widget screen) async {
  await t.pumpWidget(
    rig.wrap(
      ContactFlowApp(
        home: KeyedSubtree(key: UniqueKey(), child: screen),
      ),
    ),
  );
  await settle(t);
  expect(t.takeException(), isNull);
}

Person firstWithPhones(Rig rig) =>
    rig.book.people.firstWhere((p) => p.phones.length > 1);

void main() {
  tearDownAll(() {
    for (final o in overflowLog.toSet()) {
      debugPrint('OVERFLOW $o');
    }
  });
  for (final lang in ['en', 'ar']) {
    for (final dark in [false, true]) {
      final tag = '$lang${dark ? ' dark' : ''}';

      testWidgets('phone list at 360 px, 1.3x ($tag)', (t) async {
        small(t);
        final rig = await rigFor(t, lang, dark: dark);
        await show(t, rig, PhoneHome(onTab: (_) {}));
        expect(find.byType(PersonRow), findsWidgets);
        await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await settle(t);
        expect(t.takeException(), isNull);
        rig.book.toggle(rig.book.people.first);
        await settle(t);
        expect(find.byKey(const ValueKey('bulkMore')), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('detail and edit ($tag)', (t) async {
        small(t);
        final rig = await rigFor(t, lang, dark: dark);
        final p = firstWithPhones(rig);
        await show(t, rig, PhoneDetailScreen(id: p.id));
        expect(find.byKey(const ValueKey('reach-call')), findsOneWidget);
        await t.drag(find.byType(ListView), const Offset(0, -600));
        await settle(t);
        expect(t.takeException(), isNull);
        await show(t, rig, PhoneEditScreen(person: p));
        await t.drag(find.byType(ListView), const Offset(0, -1400));
        await settle(t);
        expect(t.takeException(), isNull);
        await show(t, rig, const PhoneEditScreen());
        expect(t.takeException(), isNull);
      });

      testWidgets('review, history, sync, merge ($tag)', (t) async {
        small(t);
        final rig = await rigFor(t, lang, dark: dark);
        final some = rig.book.people.take(4).toList();
        final edited = [
          for (final p in some)
            p.copy()
              ..name = '${p.name} Jr'
              ..org = 'Acme',
        ];
        final set = Planner.batch(some, edited);
        await show(t, rig, ChangeReviewScreen(set: set));
        expect(find.byKey(const ValueKey('applyReview')), findsOneWidget);
        await show(
          t,
          rig,
          ChangeReviewScreen(set: Planner.delete(rig.book.people.take(3))),
        );
        await t.runAsync(() => rig.book.apply(set));
        await t.runAsync(
          () => rig.book.apply(Planner.star(rig.book.people.take(2), true)),
        );
        await show(t, rig, const HistoryScreen());
        expect(find.byIcon(Icons.undo_rounded), findsWidgets);
        final rows = [
          for (final p in rig.book.people.take(5))
            Person(
              name: p.name,
              phones: p.phones,
              org: 'Updated Co',
              phoneId: p.phoneId,
            ),
          Person(
            name: 'Brand New',
            phones: [const PhoneEntry('+44 7700 000001')],
          ),
        ];
        await show(t, rig, SyncScreen(rows: rows));
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('grp-update')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(t);
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('policy-overwrite')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.byKey(const ValueKey('policy-overwrite')));
        await settle(t);
        expect(t.takeException(), isNull);
        await show(t, rig, const MergeScreen());
        expect(find.byKey(const ValueKey('dup-0')), findsOneWidget);
        await t.drag(find.byType(ListView), const Offset(0, -800));
        await settle(t);
        expect(t.takeException(), isNull);
      });

      testWidgets('compose, queue and settings ($tag)', (t) async {
        small(t);
        final rig = await rigFor(t, lang, dark: dark);
        final people = rig.book.people.take(6).toList();
        await show(t, rig, ComposeScreen(people: people));
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('composeText')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(
          find.byKey(const ValueKey('composeText')),
          'Hi {first} from {company}',
        );
        await settle(t);
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('mode-group')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.byKey(const ValueKey('mode-group')));
        await settle(t);
        expect(t.takeException(), isNull);
        await t.runAsync(
          () => rig.queue.start(people, 'Hi {first}', channel: Channel.sms),
        );
        await show(t, rig, const QueueScreen());
        expect(find.byKey(const ValueKey('queueCurrent')), findsOneWidget);
        await show(
          t,
          rig,
          Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSettings(c),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await settle(t);
        expect(find.byKey(const ValueKey('set-history')), findsOneWidget);
        await t.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -900),
        );
        await settle(t);
        expect(t.takeException(), isNull);
      });

      testWidgets('permission states ($tag)', (t) async {
        small(t);
        for (final (access, key) in [
          (Access.notAsked, 'state-explain'),
          (Access.denied, 'state-denied'),
          (Access.blocked, 'state-blocked'),
          (Access.unsupported, 'state-unsupported'),
        ]) {
          final rig = await rigFor(t, lang, dark: dark, access: access);
          await show(t, rig, PhoneHome(onTab: (_) {}));
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '$access');
        }
        final rig = await rigFor(t, lang, dark: dark, access: Access.granted);
        await show(t, rig, PhoneHome(onTab: (_) {}));
        expect(find.byKey(const ValueKey('phoneSearch')), findsOneWidget);
      });
    }
  }

  testWidgets('create → edit → delete → undo through the UI', (t) async {
    small(t);
    final rig = await rigFor(t, 'en');
    final start = rig.source.size;
    await show(t, rig, PhoneHome(onTab: (_) {}));
    await t.tap(find.byKey(const ValueKey('newContact')));
    await settle(t);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('editName')),
        matching: find.byType(TextField),
      ),
      'Zed Tester',
    );
    await t.enterText(
      find.byKey(const ValueKey('editPhone0')),
      '+44 7700 123456',
    );
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('editSave')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(t);
    expect(rig.source.size, start + 1);
    final made = rig.book.people.firstWhere((p) => p.name == 'Zed Tester');
    expect(find.byKey(const ValueKey('resultSnack')), findsOneWidget);

    await t.pumpWidget(
      rig.wrap(ContactFlowApp(home: PhoneDetailScreen(id: made.id))),
    );
    await settle(t);
    await t.tap(find.byKey(const ValueKey('detailEdit')));
    await settle(t);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('editName')),
        matching: find.byType(TextField),
      ),
      'Zed Edited',
    );
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('editSave')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(t);
    expect(rig.book.people.any((p) => p.name == 'Zed Edited'), isTrue);

    await t.tap(find.byKey(const ValueKey('detailDelete')));
    await settle(t);
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('confirmDelete')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(t);
    expect(rig.source.size, start);
    final entry = rig.book.journal.entries.first;
    expect(entry.canUndo, isTrue);
    await t.runAsync(() => rig.book.undo(entry));
    await settle(t);
    expect(rig.source.size, start + 1);
    expect(rig.book.people.any((p) => p.name == 'Zed Edited'), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('5,000 contacts render and scroll smoothly', (t) async {
    small(t);
    SharedPreferences.setMockInitialValues({'lang': 'en'});
    final app = AppState();
    await t.runAsync(() => app.init(openStore: false));
    final seed = [
      for (var i = 0; i < 5000; i++)
        Person(
          name:
              'Contact ${String.fromCharCode(65 + i % 26)}${i.toString().padLeft(4, '0')}',
          phones: [PhoneEntry('+4477009${i.toString().padLeft(5, '0')}')],
        ),
    ];
    final rig = (await t.runAsync(() => makeRig(app: app, seed: seed)))!;
    await t.runAsync(() => rig.book.checkAccess());
    final sw = Stopwatch()..start();
    await show(t, rig, PhoneHome(onTab: (_) {}));
    for (var i = 0; i < 10; i++) {
      await t.fling(
        find.byType(CustomScrollView),
        const Offset(0, -3000),
        8000,
      );
      await t.pump(const Duration(milliseconds: 300));
    }
    sw.stop();
    expect(t.takeException(), isNull);
    expect(rig.book.people.length, 5000);
    expect(find.byType(PersonRow).evaluate().length, lessThan(40));
  });

  testWidgets('queue resumes after a restart', (t) async {
    small(t);
    final rig = await rigFor(t, 'en');
    final five = rig.book.people.where((p) => p.hasNumber).take(5).toList();
    await t.runAsync(
      () => rig.queue.start(five, 'Hi {first}', channel: Channel.sms),
    );
    await show(t, rig, const QueueScreen());
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('queueOpen')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await settle(t);
    expect(rig.launcher.opened.single.scheme, 'smsto');
    await t.tap(find.byKey(const ValueKey('queueOpen')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('queueSkip')));
    await settle(t);
    expect(rig.queue.queue!.handled, 2);

    final again = (await t.runAsync(() => makeRig(app: rig.app, kv: rig.kv)))!;
    expect(again.queue.active, isTrue);
    expect(again.queue.queue!.handled, 2);
    expect(again.queue.queue!.current!.name, five[2].displayName);
    await show(t, again, const QueueScreen());
    expect(find.text(five[2].displayName), findsWidgets);
    await t.tap(find.byKey(const ValueKey('queueStop')));
    await settle(t);
    expect(again.queue.queue!.finished, isTrue);
  });

  test('storage size is human readable', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
  });
}
