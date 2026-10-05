import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/phone_book.dart';
import 'home.dart';
import 'phone_home.dart';

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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      child: tab == 0
          ? PhoneHome(key: const ValueKey('phone'), onTab: go)
          : HomeScreen(key: const ValueKey('files'), onTab: go),
    );
  }
}
