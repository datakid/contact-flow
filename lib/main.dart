import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/contact_source.dart';
import 'data/journal.dart';
import 'data/phone_source.dart';
import 'data/sample.dart';
import 'models/person.dart';
import 'l10n.dart';
import 'services/launcher.dart';
import 'services/library_store.dart';
import 'state/app_state.dart';
import 'state/phone_book.dart';
import 'state/queue_state.dart';
import 'ui/root.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  await state.init();
  final ContactSource source = PhoneSource.supported
      ? PhoneSource()
      : FakeSource(
          seed: Sample.phoneBook(),
          accounts: const [AccountRef.device, Sample.google],
          access: Access.unsupported,
        );
  final book = PhoneBook(source, Journal(HiveJournalStore()));
  book.sortLang = state.lang;
  final queue = QueueState(HiveKeyValue(), const SystemLauncher());
  await queue.load();
  runApp(
    AppProviders(
      state: state,
      book: book,
      queue: queue,
      launcher: const SystemLauncher(),
      child: const ContactFlowApp(),
    ),
  );
}

class AppProviders extends StatelessWidget {
  final AppState state;
  final PhoneBook book;
  final QueueState queue;
  final Launcher launcher;
  final Widget child;
  const AppProviders({
    super.key,
    required this.state,
    required this.book,
    required this.queue,
    required this.launcher,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: book),
      ChangeNotifierProvider.value(value: queue),
      Provider<Launcher>.value(value: launcher),
    ],
    child: child,
  );
}

class ContactFlowApp extends StatelessWidget {
  final Widget? home;
  const ContactFlowApp({super.key, this.home});

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
        home: home ?? const WorkspaceRoot(),
      ),
    );
  }
}

bool _fontsRegistered = false;

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
