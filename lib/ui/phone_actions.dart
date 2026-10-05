import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/planner.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'batch_screen.dart';
import 'compose_screen.dart';
import 'export_screen.dart';
import 'history_screen.dart';
import 'merge_screen.dart';
import 'pipeline.dart';
import 'reach_ui.dart';
import 'sync_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> startCompose(BuildContext context, List<Person> people) =>
    openCompose(context, people);

Future<bool> savePhoneBatch(
  BuildContext context,
  List<Person> originals,
  List<Person> edited,
) async {
  final r = await applyChanges(context, Planner.batch(originals, edited));
  return r != null;
}

Future<void> openPhoneBatch(BuildContext context, List<Person> people) =>
    openBatchEditor(
      context,
      people,
      onSave: (c, originals, edited) => savePhoneBatch(c, originals, edited),
    );

class _SheetAction {
  final IconData icon;
  final String label;
  final String? sub;
  final Future<void> Function() run;
  final bool danger;
  final Key? key;
  const _SheetAction(
    this.icon,
    this.label,
    this.run, {
    this.sub,
    this.danger = false,
    this.key,
  });
}

Future<void> _actionSheet(
  BuildContext context,
  String title,
  List<_SheetAction> actions,
) async {
  final p = context.pal;
  final picked = await showModalBottomSheet<_SheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 16 + MediaQuery.of(c).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(title, style: Type.display(p, size: 32)),
          ),
          for (final a in actions)
            ListTile(
              key: a.key,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(a.icon, color: a.danger ? p.accent : p.ink),
              title: Text(
                a.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: a.danger ? p.accent : p.ink,
                ),
              ),
              subtitle: a.sub == null
                  ? null
                  : Text(a.sub!, style: TextStyle(color: p.inkSoft)),
              onTap: () => Navigator.pop(c, a),
            ),
        ],
      ),
    ),
  );
  if (picked != null) await picked.run();
}

Future<void> openPhoneTools(BuildContext context) {
  final l = L.of(context);
  final book = context.read<PhoneBook>();
  final all = book.visible;
  return _actionSheet(context, l.t('tools'), [
    _SheetAction(
      Icons.merge_rounded,
      l.t('duplicates'),
      () => openMerge(context),
      sub: l.t('duplicatesSub'),
      key: const ValueKey('tool-merge'),
    ),
    _SheetAction(
      Icons.sync_rounded,
      l.t('syncFromFile'),
      () => pickAndSync(context),
      sub: l.t('syncFromFileSub'),
      key: const ValueKey('tool-sync'),
    ),
    _SheetAction(
      Icons.table_rows_outlined,
      l.t('batchEdit'),
      () => openPhoneBatch(context, all),
      sub: l.n(all.length, 'contacts_one', 'contacts_many'),
      key: const ValueKey('tool-batch'),
    ),
    _SheetAction(
      Icons.north_east_rounded,
      l.t('export'),
      () => openExport(context, all),
      sub: l.t('exportWithId'),
      key: const ValueKey('tool-export'),
    ),
    _SheetAction(
      Icons.forum_outlined,
      l.t('message'),
      () => openCompose(context, all),
      sub: l.t('messageSub'),
    ),
    _SheetAction(
      Icons.history_rounded,
      l.t('history'),
      () => openHistory(context),
      sub: l.t('historySub'),
      key: const ValueKey('tool-history'),
    ),
  ]);
}

Future<void> openSelectionActions(BuildContext context, List<Person> people) {
  final l = L.of(context);
  final book = context.read<PhoneBook>();
  final anyUnstarred = people.any((p) => !p.starred);
  return _actionSheet(
    context,
    l.n(people.length, 'selected_one', 'selected_many'),
    [
      _SheetAction(
        anyUnstarred ? Icons.star_rounded : Icons.star_outline_rounded,
        anyUnstarred ? l.t('star') : l.t('unstar'),
        () async {
          final r = await applyChanges(
            context,
            Planner.star(people, anyUnstarred),
            review: false,
          );
          if (r != null) book.clearSelection();
        },
        key: const ValueKey('sel-star'),
      ),
      _SheetAction(
        Icons.label_outline_rounded,
        l.t('addToGroup'),
        () async {
          final g = await pickGroup(context, book.allGroups.toList()..sort());
          if (g == null || !context.mounted) return;
          final r = await applyChanges(context, Planner.group(people, g, true));
          if (r != null) book.clearSelection();
        },
        key: const ValueKey('sel-group'),
      ),
      if (people.any((p) => p.groups.isNotEmpty))
        _SheetAction(
          Icons.label_off_outlined,
          l.t('removeFromGroup'),
          () async {
            final groups = {for (final p in people) ...p.groups}.toList()
              ..sort();
            final g = await pickGroup(context, groups, allowNew: false);
            if (g == null || !context.mounted) return;
            final r = await applyChanges(
              context,
              Planner.group(people, g, false),
            );
            if (r != null) book.clearSelection();
          },
        ),
      _SheetAction(
        Icons.table_rows_outlined,
        l.t('batchEdit'),
        () => openPhoneBatch(context, people),
      ),
      _SheetAction(
        Icons.north_east_rounded,
        l.t('export'),
        () => openExport(context, people),
      ),
      _SheetAction(
        Icons.ios_share_rounded,
        l.t('shareVcard'),
        () => shareContact(context, people),
      ),
      _SheetAction(
        Icons.copy_all_rounded,
        l.t('copyNumbers'),
        () => copyNumbers(context, people),
      ),
      _SheetAction(
        Icons.merge_rounded,
        l.t('mergeSelected'),
        () => openMerge(context, only: people),
      ),
      _SheetAction(Icons.delete_outline_rounded, l.t('delete'), () async {
        final r = await applyChanges(
          context,
          Planner.delete(people),
          review: false,
        );
        if (r != null) book.clearSelection();
      }, danger: true),
    ],
  );
}

Future<String?> pickGroup(
  BuildContext context,
  List<String> groups, {
  bool allowNew = true,
}) {
  final l = L.of(context);
  final p = context.pal;
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.t('groups'), style: Type.display(p, size: 28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in groups)
                  Pill(
                    label: g,
                    active: false,
                    onTap: () => Navigator.pop(ctx, g),
                  ),
              ],
            ),
            if (allowNew) ...[
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('newGroupField'),
                controller: c,
                decoration: InputDecoration(
                  hintText: l.t('newGroup'),
                  filled: true,
                  fillColor: p.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                ),
                onSubmitted: (v) =>
                    Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            l.t('cancel'),
            style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
          ),
        ),
        if (allowNew)
          TextButton(
            key: const ValueKey('groupOk'),
            onPressed: () => Navigator.pop(
              ctx,
              c.text.trim().isEmpty ? null : c.text.trim(),
            ),
            child: Text(
              l.t('done'),
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    ),
  );
}
