import 'package:flutter/material.dart';

import '../l10n.dart';
import 'theme.dart';
import 'widgets.dart';
import '../services/edition.dart';

class ScreenTitle extends StatelessWidget {
  final String text;
  const ScreenTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, maxLines: 1, style: AppText.display(p, size: 32)),
    );
  }
}

const tabContacts = 0;
const tabFiles = 1;
const tabCalls = 2;
const tabTags = 3;

List<int> navTabs({required bool tags}) => [
  tabContacts,
  if (callsBuild) tabCalls,
  if (tags) tabTags,
  tabFiles,
];

class AppNavBar extends StatelessWidget {
  final int tab;
  final bool tags;
  final ValueChanged<int> onChanged;
  const AppNavBar({
    super.key,
    required this.tab,
    required this.tags,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final order = navTabs(tags: tags);
    final (label, icon, selected) = (
      <int, String>{
        tabContacts: l.t('navContacts'),
        tabCalls: l.t('wsCalls'),
        tabTags: l.t('tagsTitle'),
        tabFiles: l.t('wsFiles'),
      },
      <int, IconData>{
        tabContacts: Icons.contacts_outlined,
        tabCalls: Icons.phone_callback_outlined,
        tabTags: Icons.label_outline_rounded,
        tabFiles: Icons.folder_open_rounded,
      },
      <int, IconData>{
        tabContacts: Icons.contacts_rounded,
        tabCalls: Icons.phone_callback_rounded,
        tabTags: Icons.label_rounded,
        tabFiles: Icons.folder_rounded,
      },
    );
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: p.sheet,
        indicatorColor: p.accentSoft,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? p.ink : p.inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accentText : p.inkSoft,
          ),
        ),
      ),
      child: NavigationBar(
        key: const ValueKey('nav-bar'),
        selectedIndex: order.indexOf(tab).clamp(0, order.length - 1),
        onDestinationSelected: (i) => onChanged(order[i]),
        destinations: [
          for (final t in order)
            NavigationDestination(
              key: ValueKey('nav-$t'),
              icon: Icon(icon[t]),
              selectedIcon: Icon(selected[t]),
              label: label[t]!,
            ),
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
          Text(title, style: AppText.display(p, size: 34)),
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
