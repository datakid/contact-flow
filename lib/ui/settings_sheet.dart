import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../services/file_out.dart';
import '../state/app_state.dart';
import '../state/phone_book.dart';
import 'history_screen.dart';
import 'reach_ui.dart';
import 'theme.dart';
import 'widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../calls/ignore_book.dart';
import '../services/data_move.dart';
import '../services/incoming_read.dart';
import '../tags/tag_book.dart';
import 'ignored_sheet.dart';
import 'tags_screen.dart';
import 'group_tags_sheet.dart';

const appVersion = '3.0.0';

Future<void> showSettings(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _Settings(),
  );
}

class _Settings extends StatelessWidget {
  const _Settings();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = L.of(context);
    final p = context.pal;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Text(l.t('settings'), style: Type.display(p, size: 40)),
          ),
          SectionLabel(l.t('theme')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final m in [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ]) ...[
                  Expanded(
                    child: _ThemeTile(
                      mode: m,
                      active: s.themeMode == m,
                      onTap: () => s.setTheme(m),
                    ),
                  ),
                  if (m != ThemeMode.dark) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          SectionLabel(l.t('language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in L.langs.entries)
                  Pill(
                    label: e.value,
                    active: s.lang == e.key,
                    onTap: () => s.setLang(e.key),
                  ),
              ],
            ),
          ),
          SectionLabel(l.t('wsPhone')),
          _Action(
            key: const ValueKey('set-history'),
            icon: Icons.history_rounded,
            label: l.t('history'),
            sub: l.t('historySub'),
            onTap: () {
              Navigator.pop(context);
              openHistory(context);
            },
          ),
          _Action(
            key: const ValueKey('set-country'),
            icon: Icons.public_rounded,
            label: l.t('defaultCountry'),
            sub: s.country.isEmpty
                ? l.t('notSet')
                : (s.needsRegionPick
                      ? l.t('regionPick')
                      : '${s.country} · ${regionFlag(s.region)} ${s.region}'),
            onTap: () async {
              await askCountry(context, force: true);
              if (!context.mounted) return;
              final tagBook = _maybe<TagBook>(context);
              if (tagBook == null) return;
              final moved = await tagBook.rekeyUnparsed();
              if (moved > 0 && context.mounted) {
                toast(context, l.t('tagsMoved', {'n': moved}));
              }
            },
          ),
          Builder(
            builder: (context) {
              final book = context.watch<PhoneBook>();
              return _Action(
                icon: Icons.contacts_outlined,
                label: l.t('contactsAccess'),
                sub: l.t('access_${book.access.name}'),
                onTap: book.isDevice ? book.openSettings : null,
              );
            },
          ),
          SectionLabel(l.t('library')),
          if (_maybe<IgnoreBook>(context) case final ignored?)
            _Action(
              key: const ValueKey('set-ignored'),
              icon: Icons.phone_disabled_rounded,
              label: l.t('ignoredTitle'),
              sub: l.t('ignoredCount', {'n': ignored.keys.length}),
              onTap: () => showIgnoredSheet(context),
            ),
          if (_maybe<TagBook>(context) case final tagBook?)
            _Action(
              key: const ValueKey('set-tags'),
              icon: Icons.label_outline_rounded,
              label: l.t('tagsTitle'),
              sub: l.t('tagNumbers', {'n': tagBook.tags.length}),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TagsScreen()),
              ),
            ),
          if (_maybe<TagBook>(context) != null)
            _Action(
              key: const ValueKey('set-group-tags'),
              icon: Icons.group_work_outlined,
              label: l.t('groupTagsTitle'),
              sub: l.t('groupTagsSub'),
              onTap: () => showGroupTagsSheet(context),
            ),
          if (_maybe<TagBook>(context) case final tags?)
            if (_maybe<IgnoreBook>(context) case final ignore?) ...[
              _Action(
                key: const ValueKey('set-move-export'),
                icon: Icons.upload_file_rounded,
                label: l.t('moveExport'),
                sub: l.t('moveSub'),
                onTap: () async {
                  final json = DataMove.export(
                    people: s.people,
                    tags: tags,
                    ignore: ignore,
                  );
                  await shareBytes(
                    Uint8List.fromList(utf8.encode(json)),
                    'contact-flow-data.json',
                    'application/json',
                  );
                },
              ),
              _Action(
                key: const ValueKey('set-move-import'),
                icon: Icons.download_rounded,
                label: l.t('moveImport'),
                sub: l.t('moveSub'),
                onTap: () async {
                  final res = await FilePicker.pickFiles(
                    withData: kIsWeb,
                    type: FileType.any,
                  );
                  final f = res == null || res.files.isEmpty
                      ? null
                      : res.files.first;
                  if (f == null) return;
                  var bytes = f.bytes;
                  final path = f.path;
                  if (bytes == null && path != null && !kIsWeb) {
                    bytes = await readFileBytes(path);
                  }
                  if (bytes == null) {
                    if (context.mounted) toast(context, l.t('moveBad'));
                    return;
                  }
                  try {
                    final r = await DataMove.import(
                      utf8.decode(bytes, allowMalformed: true),
                      state: s,
                      tags: tags,
                      ignore: ignore,
                    );
                    if (context.mounted) {
                      toast(
                        context,
                        l.t('moveDone', {
                          'n': r.people,
                          'm': r.tags,
                          'k': r.ignored,
                        }),
                      );
                    }
                  } on FormatException {
                    if (context.mounted) toast(context, l.t('moveBad'));
                  }
                },
              ),
            ],
          if (s.quarantined > 0)
            _Action(
              key: const ValueKey('set-quarantine'),
              icon: Icons.report_problem_outlined,
              label: l.t('quarantineCount', {'n': s.quarantined}),
              sub: l.t('quarantineExport'),
              onTap: () async {
                final json = await s.quarantineJson();
                await shareBytes(
                  Uint8List.fromList(utf8.encode(json)),
                  'unreadable-items.json',
                  'application/json',
                );
              },
            ),
          _Action(
            icon: Icons.merge_rounded,
            label: l.t('dedupe'),
            onTap: s.people.isEmpty
                ? null
                : () async {
                    final plan = s.planDedupe();
                    if (plan.isEmpty) {
                      toast(context, l.t('dedupeNone'));
                      return;
                    }
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(l.t('dedupe')),
                        content: Text(
                          [
                            l.t('dedupePreview', {'n': plan.removed}),
                            ...plan.groups
                                .take(5)
                                .map((g) => g.keep.displayName),
                          ].join('\n'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(l.t('cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(l.t('dedupeMerge')),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final undo = await s.applyDedupe(plan);
                    if (context.mounted) {
                      toast(
                        context,
                        l.t('dedupeDone', {'n': plan.removed}),
                        action: l.t('undo'),
                        onAction: () => s.undoDedupe(undo),
                        duration: const Duration(seconds: 8),
                      );
                    }
                  },
          ),
          _Action(
            icon: Icons.layers_clear_rounded,
            label: l.t('clearLibrary'),
            danger: true,
            onTap: s.people.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(
                          l.t('clearLibrary'),
                          style: Type.display(p, size: 28),
                        ),
                        content: Text(
                          l.t('clearConfirm'),
                          style: TextStyle(color: p.inkSoft, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(
                              l.t('cancel'),
                              style: TextStyle(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(
                              l.t('remove'),
                              style: TextStyle(
                                color: p.accentText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await s.clearAll();
                  },
          ),
          SectionLabel(l.t('about')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('aboutBody'),
                  style: Type.display(
                    p,
                    size: 21,
                    italic: true,
                  ).copyWith(color: p.inkSoft, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 15, color: p.sage),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.t('privacy'),
                        style: TextStyle(
                          color: p.sageText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contact Flow $appVersion · MIT',
                        style: Type.label(p),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'Contact Flow',
                          applicationVersion: appVersion,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: p.accentText,
                        ),
                        child: Text(
                          l.t('licenses'),
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemeMode mode;
  final bool active;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.mode,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final l = L.of(context);
    final label = switch (mode) {
      ThemeMode.light => l.t('light'),
      ThemeMode.dark => l.t('dark'),
      _ => l.t('system'),
    };
    Widget swatch(Palette x) => Container(
      decoration: BoxDecoration(
        color: x.paper,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 5,
            decoration: BoxDecoration(
              color: x.ink,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: x.inkFaint,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: x.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? p.ink : p.hairline,
            width: active ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: mode == ThemeMode.system
                    ? Row(
                        children: [
                          Expanded(child: swatch(Palette.light)),
                          Expanded(child: swatch(Palette.dark)),
                        ],
                      )
                    : swatch(
                        mode == ThemeMode.dark ? Palette.dark : Palette.light,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final String? sub;
  const _Action({
    super.key,
    this.sub,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = danger ? p.accentText : p.ink;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon, color: c),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: c),
        ),
        subtitle: sub == null
            ? null
            : Text(sub!, style: TextStyle(color: p.inkSoft)),
      ),
    );
  }
}

T? _maybe<T>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}
