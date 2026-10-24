import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/ui/search_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<AppState> started([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues({'lang': 'en', ...prefs});
  final s = AppState();
  await s.init(openStore: false);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('state', () {
    test('remembers distinct searches, newest first, at most ten', () async {
      final s = await started();
      for (var i = 0; i < 12; i++) {
        await s.rememberSearch('query $i');
      }
      await s.rememberSearch('query 5');
      expect(s.recent.length, 10);
      expect(s.recent.first, 'query 5');
      expect(s.recent.where((e) => e == 'query 5').length, 1);
    });

    test('ignores very short searches', () async {
      final s = await started();
      await s.rememberSearch(' a ');
      await s.rememberSearch('');
      expect(s.recent, isEmpty);
    });

    test('recent searches survive a restart', () async {
      final s = await started();
      await s.rememberSearch('*36');
      final again = AppState();
      await again.init(openStore: false);
      expect(again.recent, ['*36']);
    });

    test('forgetting clears them', () async {
      final s = await started();
      await s.rememberSearch('*36');
      await s.forgetRecent();
      expect(s.recent, isEmpty);
    });

    test('saving pins a search and removes it from recent', () async {
      final s = await started();
      await s.rememberSearch('*36');
      await s.saveSearch('*36');
      expect(s.saved, ['*36']);
      expect(s.recent, isEmpty);
      await s.rememberSearch('*36');
      expect(s.recent, isEmpty);
    });

    test('unsaving removes it and saved searches survive a restart', () async {
      final s = await started();
      await s.saveSearch('02*36');
      await s.saveSearch('#vip');
      final again = AppState();
      await again.init(openStore: false);
      expect(again.saved, ['#vip', '02*36']);
      await again.unsaveSearch('#vip');
      expect(again.saved, ['02*36']);
    });
  });

  group('widgets', () {
    Future<(Widget, AppState)> host(
      WidgetTester t, {
      Map<String, Object> prefs = const {},
      ValueChanged<String>? onPick,
    }) async {
      SharedPreferences.setMockInitialValues({'lang': 'en', ...prefs});
      final app = AppState();
      await t.runAsync(() => app.init(openStore: false));
      final rig = (await t.runAsync(() => makeRig(app: app)))!;
      return (
        rig.wrap(
          ContactFlowApp(
            home: Scaffold(
              body: Column(
                children: [
                  RecentSearchChips(onPick: onPick ?? (_) {}),
                  SaveSearchButton(list: rig.app),
                ],
              ),
            ),
          ),
        ),
        rig.app,
      );
    }

    testWidgets('chips list saved and recent searches and pick one', (t) async {
      String? picked;
      final (w, _) = await host(
        t,
        prefs: {
          'recentSearches': ['*36'],
          'savedSearches': ['#vip'],
        },
        onPick: (q) => picked = q,
      );
      await t.pumpWidget(w);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-#vip')), findsOneWidget);
      expect(find.byKey(const ValueKey('recent-*36')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('recent-*36')));
      expect(picked, '*36');
    });

    testWidgets('nothing shows when there is no history', (t) async {
      final (w, _) = await host(t);
      await t.pumpWidget(w);
      await t.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('the save button appears for a pattern and pins it', (t) async {
      final (w, app) = await host(t);
      await t.pumpWidget(w);
      app.setQuery('*36');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('save-search')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('save-search')));
      await t.pump();
      expect(app.saved, ['*36']);
      expect(find.byKey(const ValueKey('save-search')), findsNothing);
    });

    testWidgets('the save button is hidden for plain names', (t) async {
      final (w, app) = await host(t);
      await t.pumpWidget(w);
      app.setQuery('ahmed');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('save-search')), findsNothing);
    });
  });
}
