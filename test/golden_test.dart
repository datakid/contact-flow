@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_test.dart';

String slug(String s) =>
    s.replaceAll(' ', '_').replaceAll('.', '_').toLowerCase();

void main() {
  setUpAll(() async {
    final bytes = await File('test/fonts/NotoSansArabic.ttf').readAsBytes();
    final loader = FontLoader('Noto Sans Arabic')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
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
