import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class StoreErrorScreen extends StatefulWidget {
  const StoreErrorScreen({super.key});

  @override
  State<StoreErrorScreen> createState() => _StoreErrorScreenState();
}

class _StoreErrorScreenState extends State<StoreErrorScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await context.read<AppState>().retryStore();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: p.accent, size: 36),
              const SizedBox(height: 16),
              Text(l.t('storeErrorTitle'), style: Type.display(p, size: 30)),
              const SizedBox(height: 12),
              Text(
                l.t('storeErrorBody'),
                style: TextStyle(color: p.inkSoft, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: l.t('tryAgain'),
                  icon: Icons.refresh_rounded,
                  busy: _busy,
                  onTap: _busy ? null : _retry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
