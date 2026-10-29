@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_test.dart';

String slug(String s) =>
    s.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();

void main() {
  setUpAll(() async {
    Future<ByteData> bytes(String path) async {
      final b = await File(path).readAsBytes();
      return ByteData.sublistView(b);
    }

    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(bytes(f));
      }
      await loader.load();
    }

    await load('Manrope', [
      for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Manrope-$w.ttf',
    ]);
    await load('Instrument', [
      'assets/fonts/InstrumentSerif-Regular.ttf',
      'assets/fonts/InstrumentSerif-Italic.ttf',
    ]);
    await load('Noto Sans Arabic', ['test/fonts/NotoSansArabic.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      await load('MaterialIcons', [
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ]);
    }
  });

  for (final s in setups) {
    screens.forEach((screen, tab) {
      testWidgets('$screen golden (${s.name})', (t) async {
        await pumpScreen(t, s, tab);
        await expectLater(
          find.byType(Navigator).first,
          matchesGoldenFile('goldens/${screen}_${slug(s.name)}.png'),
        );
      });
    });
  }
}
