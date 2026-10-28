import 'dart:io';

import 'package:contact_flow/main.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:contact_flow/ui/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

class Setup {
  final String name;
  final String lang;
  final bool dark;
  final double scale;
  final Size size;
  const Setup(this.name, this.lang, this.dark, this.scale, this.size);
}

const phone = Size(360, 800);

final setups = [
  for (final lang in ['en', 'ar'])
    for (final dark in [false, true])
      for (final scale in [1.0, 2.0])
        Setup(
          '$lang ${dark ? 'dark' : 'light'} x$scale',
          lang,
          dark,
          scale,
          phone,
        ),
  const Setup('narrow en light x2.0', 'en', false, 2.0, Size(320, 640)),
];

const screens = {
  'contacts': tabContacts,
  'files': tabFiles,
  'tags': tabTags,
};

Future<void> pumpScreen(WidgetTester t, Setup s, int tab) async {
  t.view.physicalSize = s.size * 3;
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = s.scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({
    'lang': s.lang,
    'theme': s.dark ? 2 : 1,
    'tab': tab,
    'country': '+44',
  });
  final app = AppState();
  await t.runAsync(() => app.init(openStore: false));
  final rig = (await t.runAsync(() => makeRig(app: app)))!;
  rig.book.sortLang = s.lang;
  await t.runAsync(() => rig.book.checkAccess());
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
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() async {
    final bytes = await File('test/fonts/NotoSansArabic.ttf').readAsBytes();
    final loader = FontLoader('Noto Sans Arabic')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  for (final s in setups) {
    screens.forEach((screen, tab) {
      testWidgets('$screen has no overflow (${s.name})', (t) async {
        await pumpScreen(t, s, tab);
        expect(t.takeException(), isNull);
      });

      testWidgets('$screen tap targets are 48 dp (${s.name})', (t) async {
        final handle = t.ensureSemantics();
        await pumpScreen(t, s, tab);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('$screen tap targets are labelled (${s.name})', (t) async {
        final handle = t.ensureSemantics();
        await pumpScreen(t, s, tab);
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  }
}
