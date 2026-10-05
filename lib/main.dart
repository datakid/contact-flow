import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'state/app_state.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  await state.init();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const ContactFlowApp()),
  );
}

class ContactFlowApp extends StatelessWidget {
  const ContactFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    final lang = context.select<AppState, String>((s) => s.lang);
    final l = L(lang);
    Type.spaced = lang != 'ar';
    return LScope(
      l: l,
      child: MaterialApp(
        title: 'Contact Flow',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeAnimationDuration: const Duration(milliseconds: 380),
        themeAnimationCurve: Curves.easeOutCubic,
        locale: Locale(lang),
        supportedLocales: L.langs.keys.map(Locale.new).toList(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final b = Theme.of(context).brightness;
          final p = context.pal;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (b == Brightness.light
                        ? SystemUiOverlayStyle.dark
                        : SystemUiOverlayStyle.light)
                    .copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: p.paper,
                      systemNavigationBarIconBrightness: b == Brightness.light
                          ? Brightness.dark
                          : Brightness.light,
                    ),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}

bool _fontsRegistered = false;

/// Bundled fonts are SIL OFL 1.1; the license must travel with the app.
void registerFontLicenses() {
  if (_fontsRegistered) return;
  _fontsRegistered = true;
  LicenseRegistry.addLicense(_fontLicenses);
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final (pkg, file) in const [
    ('Manrope', 'assets/fonts/OFL-Manrope.txt'),
    ('Instrument Serif', 'assets/fonts/OFL-InstrumentSerif.txt'),
  ]) {
    try {
      yield LicenseEntryWithLineBreaks([
        pkg,
      ], await rootBundle.loadString(file));
    } catch (_) {}
  }
}
