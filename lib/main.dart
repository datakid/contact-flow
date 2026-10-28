import 'package:dynamic_color/dynamic_color.dart';
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
import 'tags/tag_book.dart';
import 'tags/tag_store.dart';
import 'ui/root.dart';
import 'ui/store_error.dart';
import 'ui/theme.dart';
import 'calls/ignore_book.dart';
import 'services/edition.dart';
import 'ui/edition_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  await state.init(detectRegion: true);
  final badEdition = Edition.mismatch(await Edition.nativeName());
  if (badEdition != null) {
    runApp(EditionErrorApp(native: badEdition, lang: state.lang));
    return;
  }
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
  final tags = TagBook(HiveTagStore());
  try {
    await tags.load();
  } catch (_) {}
  final ignore = IgnoreBook(HiveTagStore(boxName: 'ignore_v1'));
  try {
    await ignore.load();
  } catch (_) {}
  state.tagMatcher = tags.personHasTag;
  book.tagMatcher = tags.personHasTag;
  runApp(
    AppProviders(
      state: state,
      book: book,
      queue: queue,
      launcher: const SystemLauncher(),
      tags: tags,
      ignore: ignore,
      child: const ContactFlowApp(),
    ),
  );
}

class AppProviders extends StatelessWidget {
  final AppState state;
  final PhoneBook book;
  final QueueState queue;
  final Launcher launcher;
  final TagBook? tags;
  final IgnoreBook? ignore;
  final Widget child;
  const AppProviders({
    super.key,
    required this.state,
    required this.book,
    required this.queue,
    required this.launcher,
    required this.child,
    this.tags,
    this.ignore,
  });

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: book),
      ChangeNotifierProvider.value(value: queue),
      if (tags != null) ChangeNotifierProvider.value(value: tags!),
      if (ignore != null) ChangeNotifierProvider.value(value: ignore!),
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
    final storeFailed = context.select<AppState, bool>((s) => s.storeFailed);
    final lang = context.select<AppState, String>((s) => s.lang);
    final useDynamic = context.select<AppState, bool>((s) => s.dynamicColor);
    final l = L(lang);
    AppText.spaced = lang != 'ar';
    if (!useDynamic) return _app(mode, storeFailed, lang, l, null, null);
    return DynamicColorBuilder(
      builder: (light, dark) => _app(mode, storeFailed, lang, l, light, dark),
    );
  }

  Widget _app(
    ThemeMode mode,
    bool storeFailed,
    String lang,
    L l,
    ColorScheme? light,
    ColorScheme? dark,
  ) {
    return LScope(
      l: l,
      child: MaterialApp(
        title: 'Contact Flow',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light, dynamicScheme: light),
        darkTheme: buildTheme(Brightness.dark, dynamicScheme: dark),
        themeAnimationDuration: AppMotion.slow,
        themeAnimationCurve: AppMotion.curve,
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
        home:
            home ??
            (storeFailed ? const StoreErrorScreen() : const WorkspaceRoot()),
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
