import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../io/codec.dart';
import '../io/jobs.dart';
import '../l10n.dart';
import '../services/incoming.dart';
import '../state/app_state.dart';
import '../state/phone_book.dart';
import 'home.dart';
import 'import_issues.dart';
import 'import_sheet.dart';
import 'phone_home.dart';
import '../services/edition.dart';
import 'calls_screen.dart';

int effectiveTab(AppState app, PhoneBook book) {
  if (app.tab >= 0) return app.tab;
  if (book.granted) return 0;
  return app.people.isEmpty ? 0 : 1;
}

class WorkspaceRoot extends StatefulWidget {
  const WorkspaceRoot({super.key});

  @override
  State<WorkspaceRoot> createState() => _WorkspaceRootState();
}

class _WorkspaceRootState extends State<WorkspaceRoot>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = context.read<PhoneBook>();
      if (book.load == LoadState.idle) unawaited(book.checkAccess());
      Incoming.attach(_receive);
    });
  }

  @override
  void dispose() {
    Incoming.detach(_receive);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _receive(List<IncomingFile> files) async {
    if (!mounted) return;
    final s = context.read<AppState>();
    final l = L.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final results = <ImportResult>[];
    for (final f in files) {
      try {
        final bytes = f.error == null ? await f.read() : null;
        if (bytes == null) {
          results.add(ImportResult.failed(f.name));
          continue;
        }
        results.add(await decodeInBackground(DecodeJob(f.name, bytes)));
      } catch (_) {
        results.add(ImportResult.failed(f.name));
      }
    }
    final total = results.fold<int>(0, (a, r) => a + r.people.length);
    if (total == 0) {
      final why = ImportIssues.describe(l, results);
      messenger.showSnackBar(
        SnackBar(
          content: Text(why.isEmpty ? l.t('nothingFound') : why),
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        ),
      );
      return;
    }
    final added = await nav.push<int>(
      MaterialPageRoute(builder: (_) => ReviewScreen(plan: s.plan(results))),
    );
    if (added != null && added >= 0) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.t('imported', {'n': added})),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<PhoneBook>().onResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final book = context.watch<PhoneBook>();
    final tab = effectiveTab(app, book);
    void go(int t) => app.setTab(t);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: tab == 2 && callsBuild
          ? CallsScreen(key: const ValueKey('calls'), onTab: go)
          : tab == 0
          ? PhoneHome(key: const ValueKey('phone'), onTab: go)
          : HomeScreen(key: const ValueKey('files'), onTab: go),
    );
  }
}
