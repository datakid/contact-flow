import 'package:flutter/material.dart';

import '../l10n.dart';
import 'theme.dart';
import 'widgets.dart';

class WorkspaceSwitch extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const WorkspaceSwitch({
    super.key,
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    Widget seg(int i, String label, IconData icon) {
      final on = tab == i;
      return Pressable(
        key: ValueKey('ws-$i'),
        haptic: true,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? p.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: on ? p.paper : p.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? p.paper : p.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: p.hairline, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(0, l.t('wsPhone'), Icons.smartphone_rounded),
          seg(1, l.t('wsFiles'), Icons.folder_open_rounded),
        ],
      ),
    );
  }
}

class RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool accent;
  const RoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accent ? p.accent : p.sheet,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent ? p.accent : p.hairline,
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: accent ? p.onAccent : p.ink, size: 22),
        ),
      ),
    );
  }
}

class StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final List<String> points;
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.points = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: p.accent, size: 30),
          ),
          const SizedBox(height: 24),
          Text(title, style: Type.display(p, size: 34)),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.55,
              color: p.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final pt in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: p.sage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pt,
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          for (final a in actions)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
        ],
      ),
    );
  }
}
