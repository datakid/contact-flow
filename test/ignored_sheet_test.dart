import 'package:contact_flow/calls/ignore_book.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/ignored_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

Future<Widget> hostWith(WidgetTester t, IgnoreBook ignore) async {
  SharedPreferences.setMockInitialValues({'lang': 'en'});
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  return rig.wrap(
    ChangeNotifierProvider<IgnoreBook>.value(
      value: ignore,
      child: ContactFlowApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showIgnoredSheet(c),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final en = L('en');

  testWidgets('an empty list says so', (t) async {
    final ignore = IgnoreBook(MemoryTagStore());
    await t.pumpWidget(await hostWith(t, ignore));
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ignored-empty')), findsOneWidget);
  });

  testWidgets('numbers are listed and can be suggested again with undo', (
    t,
  ) async {
    final ignore = IgnoreBook(MemoryTagStore());
    final keys = await t.runAsync(() => ignore.add(['+966501234567']));
    await t.pumpWidget(await hostWith(t, ignore));
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pumpAndSettle();
    expect(find.text('+966501234567'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('ignored-remove-${keys!.single}')));
    await t.pumpAndSettle();
    expect(ignore.keys, isEmpty);
    expect(find.text(en.t('ignoredRemoved')), findsOneWidget);

    await t.tap(find.text(en.t('undo')));
    await t.pumpAndSettle();
    expect(ignore.keys, keys.toSet());
  });
}
