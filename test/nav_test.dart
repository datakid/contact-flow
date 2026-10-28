import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/root.dart';
import 'package:contact_flow/ui/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<AppState> appWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues({'lang': 'en', ...prefs});
  final s = AppState();
  await s.init(openStore: false);
  return s;
}

void main() {
  final en = L('en');

  group('saved tab', () {
    test('old values keep their meaning', () async {
      expect((await appWith({'tab': 0})).tab, 0);
      expect((await appWith({'tab': 1})).tab, 1);
      expect((await appWith({})).tab, -1);
    });

    test('calls and tags can be remembered', () async {
      expect((await appWith({'tab': 2})).tab, 2);
      expect((await appWith({'tab': 3})).tab, 3);
    });

    test('out of range values are clamped', () async {
      expect((await appWith({'tab': 9})).tab, 3);
      expect((await appWith({'tab': -7})).tab, -1);
    });

    test('a tab that is not available falls back to contacts', () async {
      final calls = await appWith({'tab': 2});
      final tags = await appWith({'tab': 3});
      final rig = await makeRig(app: calls);
      expect(effectiveTab(calls, rig.book), tabContacts);
      expect(effectiveTab(tags, rig.book), tabContacts);
      expect(effectiveTab(tags, rig.book, tags: true), tabTags);
    });
  });

  testWidgets('the bar lists the available destinations', (t) async {
    final app = (await t.runAsync(() => appWith({'tab': 0})))!;
    final rig = (await t.runAsync(() => makeRig(app: app)))!;
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
    expect(find.byKey(const ValueKey('nav-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-$tabContacts')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-$tabTags')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-$tabFiles')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-$tabCalls')), findsNothing);
  });

  testWidgets('tapping a destination switches the screen and is remembered', (
    t,
  ) async {
    final app = (await t.runAsync(() => appWith({'tab': 0})))!;
    final rig = (await t.runAsync(() => makeRig(app: app)))!;
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
    await t.tap(find.byKey(const ValueKey('nav-$tabTags')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tags-empty')), findsOneWidget);
    expect(app.tab, tabTags);

    await t.tap(find.byKey(const ValueKey('nav-$tabFiles')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tags-empty')), findsNothing);
    expect(app.tab, tabFiles);
    expect(find.text(en.t('wsFiles')), findsWidgets);
  });
}
