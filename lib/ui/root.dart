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
import '../tags/tag_book.dart';
import 'tags_screen.dart';
import 'theme.dart';
import 'workspace.dart';

int effectiveTab(AppState app, PhoneBook book, {bool tags = false}) {
  if (app.tab >= 0) {
    final t = app.tab;
    if (t == tabCalls && !callsBuild) return tabContacts;
    if (t == tabTags && !tags) return tabContacts;
    return t;
  }
  if (book.granted) return tabContacts;
  return app.people.isEmpty ? tabContacts : tabFiles;
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
        if (f.error == 'tooLarge') {
          results.add(ImportResult.problem(f.name, ImportIssue.tooLarge));
          continue;
        }
        final path = f.path;
        if (f.error == null && f.bytes == null && path != null) {
          results.add(await decodeInBackground(DecodeJob.file(f.name, path)));
          continue;
        }
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
    var hasTags = false;
    try {
      context.watch<TagBook>();
      hasTags = true;
    } catch (_) {}
    final tab = effectiveTab(app, book, tags: hasTags);
    void go(int t) => app.setTab(t);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedSwitcher(
        duration: AppMotion.base,
        child: switch (tab) {
          tabCalls => CallsScreen(key: const ValueKey('calls'), onTab: go),
          tabTags => const TagsScreen(key: ValueKey('tags')),
          tabFiles => HomeScreen(key: const ValueKey('files'), onTab: go),
          _ => PhoneHome(key: const ValueKey('phone'), onTab: go),
        },
      ),
      bottomNavigationBar: keyboard
          ? null
          : AppNavBar(tab: tab, tags: hasTags, onChanged: go),
    );
  }
}
