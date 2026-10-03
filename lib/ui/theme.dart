import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class Palette extends ThemeExtension<Palette> {
  final Color paper;
  final Color sheet;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color hairline;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color sage;
  final Color highlight;
  final List<Color> avatars;

  const Palette({
    required this.paper,
    required this.sheet,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.sage,
    required this.highlight,
    required this.avatars,
  });

  static const light = Palette(
    paper: Color(0xFFF6F1E8),
    sheet: Color(0xFFFFFCF7),
    ink: Color(0xFF1C1A17),
    inkSoft: Color(0xFF6B655C),
    inkFaint: Color(0xFFA9A195),
    hairline: Color(0xFFE6DED1),
    accent: Color(0xFFE2603F),
    accentSoft: Color(0xFFF8E1D7),
    onAccent: Color(0xFFFFFAF5),
    sage: Color(0xFF7F927A),
    highlight: Color(0x33E2603F),
    avatars: [
      Color(0xFFEBD9C8),
      Color(0xFFDDE3D3),
      Color(0xFFE9D5D0),
      Color(0xFFD7DEE3),
      Color(0xFFE8E0C8),
      Color(0xFFE2D6E3),
    ],
  );

  static const dark = Palette(
    paper: Color(0xFF141210),
    sheet: Color(0xFF1D1A17),
    ink: Color(0xFFF2ECE3),
    inkSoft: Color(0xFFA59D91),
    inkFaint: Color(0xFF6A645B),
    hairline: Color(0xFF2C2824),
    accent: Color(0xFFF07A5A),
    accentSoft: Color(0xFF3A231B),
    onAccent: Color(0xFF1A0F0A),
    sage: Color(0xFF9DB097),
    highlight: Color(0x40F07A5A),
    avatars: [
      Color(0xFF3A2E25),
      Color(0xFF2B3328),
      Color(0xFF3A2A28),
      Color(0xFF26303A),
      Color(0xFF36321F),
      Color(0xFF33283A),
    ],
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      paper: l(paper, other.paper),
      sheet: l(sheet, other.sheet),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      inkFaint: l(inkFaint, other.inkFaint),
      hairline: l(hairline, other.hairline),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      sage: l(sage, other.sage),
      highlight: l(highlight, other.highlight),
      avatars: [
        for (var i = 0; i < avatars.length; i++)
          l(avatars[i], other.avatars[i]),
      ],
    );
  }
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

class Type {
  static bool spaced = true;
  static const sans = 'Manrope';
  static const serif = 'Instrument';
  static const fallback = [
    'Noto Sans Arabic',
    'Noto Naskh Arabic',
    'Geeza Pro',
    'PingFang SC',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static TextStyle display(
    Palette p, {
    double size = 44,
    bool italic = false,
  }) => TextStyle(
    fontFamily: serif,
    fontFamilyFallback: fallback,
    fontSize: size,
    height: spaced ? 1.02 : 1.25,
    letterSpacing: spaced ? -0.6 : 0,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: p.ink,
  );

  static TextStyle label(Palette p) => TextStyle(
    fontFamily: sans,
    fontFamilyFallback: fallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: spaced ? 1.6 : 0,
    color: p.inkFaint,
  );
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: Type.sans,
    fontFamilyFallback: Type.fallback,
  );
  final text = base.textTheme.apply(
    bodyColor: p.ink,
    displayColor: p.ink,
    fontFamily: Type.sans,
    fontFamilyFallback: Type.fallback,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.sheet,
      onSurface: p.ink,
      outline: p.hairline,
    ),
    extensions: [p],
    textTheme: text.copyWith(
      bodyLarge: text.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: text.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        color: p.inkSoft,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: p.ink,
      systemOverlayStyle: b == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.sheet,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(
        color: p.paper,
        fontFamily: Type.sans,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: Type.fallback,
      ),
      actionTextColor: p.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.hairline,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.highlight,
      selectionHandleColor: p.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.hairline,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
