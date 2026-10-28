import 'package:contact_flow/ui/theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final palettes = {'light': Palette.light, 'dark': Palette.dark};

  palettes.forEach((name, p) {
    group(name, () {
      test('text colors reach 4.5:1 on both surfaces', () {
        final text = {
          'ink': p.ink,
          'inkSoft': p.inkSoft,
          'inkFaint': p.inkFaint,
          'accentText': p.accentText,
          'sageText': p.sageText,
        };
        for (final surface in [p.paper, p.sheet]) {
          text.forEach((label, color) {
            expect(
              ratio(color, surface),
              greaterThanOrEqualTo(4.5),
              reason: label,
            );
          });
        }
      });

      test('tags stay readable on their own tint', () {
        for (final surface in [p.paper, p.sheet]) {
          for (final color in [p.accentText, p.sageText, p.inkSoft]) {
            final tint = Color.alphaBlend(
              color.withValues(alpha: 0.1),
              surface,
            );
            expect(ratio(color, tint), greaterThanOrEqualTo(4.5));
          }
        }
      });

      test('ink, soft and faint keep their order', () {
        final ink = ratio(p.ink, p.paper);
        final soft = ratio(p.inkSoft, p.paper);
        final faint = ratio(p.inkFaint, p.paper);
        expect(ink, greaterThan(soft));
        expect(soft, greaterThan(faint));
      });

      test('the primary button label is easy to read', () {
        expect(ratio(p.paper, p.ink), greaterThanOrEqualTo(7));
      });

      test('accent fills and their labels reach 3:1', () {
        expect(ratio(p.onAccent, p.accent), greaterThanOrEqualTo(3));
        expect(ratio(p.accent, p.paper), greaterThanOrEqualTo(3));
      });
    });
  });
}
