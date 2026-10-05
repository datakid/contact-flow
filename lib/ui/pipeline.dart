import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/executor.dart';
import '../data/journal.dart';
import '../domain/change_set.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'theme.dart';
import 'widgets.dart';

String fieldLabel(L l, ContactField f) => l.t('fld_${f.name}');

String fieldValue(L l, ContactField f, String raw) {
  if (raw.isEmpty) return '—';
  return switch (f) {
    ContactField.phones =>
      raw.split('\n').map((line) => line.split('\t').last).join(', '),
    ContactField.emails || ContactField.groups => raw.split('\n').join(', '),
    ContactField.starred => l.t('starredYes'),
    _ => raw.replaceAll('\n', ' '),
  };
}

String intentLabel(L l, ChangeIntent i) => l.t('intent_${i.name}');

String kindLabel(L l, ChangeKind k) => l.t('kind_${k.name}');

String accountLabel(L l, AccountRef? a) {
  final acc = a ?? AccountRef.device;
  if (acc.isLocal) return l.t('accountDevice');
  if (acc.isGoogle) {
    return acc.name.isEmpty ? 'Google' : 'Google · ${acc.name}';
  }
  if (acc.isSamsung) return 'Samsung';
  return acc.name.isEmpty ? acc.type : acc.name;
}

Future<bool> confirmDelete(BuildContext context, ChangeSet set) async {
  final l = L.of(context);
  final p = context.pal;
  final n = set.deletedContacts.length;
  final synced = set.deletesFromSyncedAccount;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(
        l.n(n, 'deleteTitleOne', 'deleteTitleN'),
        style: Type.display(p, size: 28),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('deleteBody'),
              style: TextStyle(color: p.inkSoft, height: 1.5),
            ),
            if (synced) ...[
              const SizedBox(height: 12),
              SyncedWarning(text: l.t('syncedDeleteWarn')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(
            l.t('cancel'),
            style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          key: const ValueKey('confirmDelete'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            l.t('delete'),
            style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<ExecutionResult?> applyChanges(
  BuildContext context,
  ChangeSet set, {
  bool review = true,
  String? undoOf,
}) async {
  final l = L.of(context);
  final book = context.read<PhoneBook>();
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  if (set.isEmpty) {
    toast(context, l.t('noChanges'));
    return null;
  }
  var chosen = set;
  if (review) {
    final picked = await nav.push<ChangeSet>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeReviewScreen(set: set),
      ),
    );
    if (picked == null || picked.isEmpty) return null;
    chosen = picked;
  } else if (set.intent != ChangeIntent.undo &&
      set.deletedContacts.isNotEmpty) {
    if (!context.mounted) return null;
    if (!await confirmDelete(context, set)) return null;
  }
  final showProgress = chosen.length > 5;
  if (showProgress) {
    nav.push(
      RawDialogRoute<void>(
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
          value: book,
          child: const ProgressDialog(),
        ),
      ),
    );
  }
  ExecutionResult? result;
  try {
    result = await book.apply(chosen, undoOf: undoOf);
  } finally {
    if (showProgress) nav.pop();
  }
  if (result == null) return null;
  showResult(messenger, l, book, result);
  return result;
}

void showResult(
  ScaffoldMessengerState messenger,
  L l,
  PhoneBook book,
  ExecutionResult r,
) {
  final entry = r.entry;
  final ok = entry.records
      .where((x) => x.status == ResultStatus.ok)
      .fold<int>(
        0,
        (n, x) => n + (x.kind == ChangeKind.merge ? 1 + x.removed.length : 1),
      );
  final parts = <String>[
    entry.intent == ChangeIntent.undo
        ? l.n(ok, 'undoneOne', 'undoneN')
        : l.n(ok, 'cfUpdatedOne', 'cfUpdatedN'),
    if (r.failed > 0) l.n(r.failed, 'failedOne', 'failedN'),
    if (r.cancelled) l.t('stoppedEarly'),
  ];
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      key: const ValueKey('resultSnack'),
      content: Text(parts.join(' · ')),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      duration: const Duration(seconds: 6),
      action: entry.canUndo
          ? SnackBarAction(
              label: l.t('undo'),
              onPressed: () async {
                final current = book.journal.byId(entry.id) ?? entry;
                if (!current.canUndo) return;
                final plan = book.undoPlan(current);
                if (plan.isEmpty) return;
                final res = await book.apply(plan, undoOf: current.id);
                if (res != null) {
                  showResult(messenger, l, book, res);
                }
              },
            )
          : null,
    ),
  );
}

class ProgressDialog extends StatelessWidget {
  const ProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final run = context.watch<PhoneBook>().running;
    final done = run?.progress.done ?? 0;
    final total = run?.progress.total ?? 0;
    final cancelling = run?.token.cancelled ?? false;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l.t('applying'), style: Type.display(p, size: 28)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : done / total,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.t('progressOf', {'done': done, 'total': total}),
                style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                l.t('backupFirst'),
                style: TextStyle(color: p.inkFaint, fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: cancelling
                ? null
                : () => context.read<PhoneBook>().cancelRun(),
            child: Text(
              cancelling ? l.t('stopping') : l.t('cancel'),
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class SyncedWarning extends StatelessWidget {
  final String text;
  const SyncedWarning({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.accentSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final ChangeKind? header;
  final int index;
  const _Item.header(this.header) : index = -1;
  const _Item.row(this.index) : header = null;
}

class ChangeReviewScreen extends StatefulWidget {
  final ChangeSet set;
  const ChangeReviewScreen({super.key, required this.set});

  @override
  State<ChangeReviewScreen> createState() => _ChangeReviewScreenState();
}

class _ChangeReviewScreenState extends State<ChangeReviewScreen> {
  late final Set<int> _on = {for (var i = 0; i < widget.set.length; i++) i};
  final Set<int> _open = {};
  late final Map<ChangeKind, List<int>> _byKind = () {
    final m = <ChangeKind, List<int>>{};
    for (var i = 0; i < widget.set.length; i++) {
      (m[widget.set.changes[i].kind] ??= []).add(i);
    }
    return m;
  }();

  List<_Item> get _items => [
    for (final k in ChangeKind.values)
      if (_byKind[k] case final rows?) ...[
        _Item.header(k),
        for (final i in rows) _Item.row(i),
      ],
  ];

  ChangeSet get _chosen => widget.set.where((i, _) => _on.contains(i));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final chosen = _chosen;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.t('cancel'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.t('reviewTitle'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _summary(l, p, chosen)),
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final it = items[i];
                      if (it.header != null) return _header(l, p, it.header!);
                      return _row(l, p, it.index);
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const ValueKey('applyReview'),
                label: chosen.isEmpty
                    ? l.t('nothingSelected')
                    : l.n(chosen.length, 'applyChangeOne', 'applyChangeN'),
                icon: Icons.check_rounded,
                onTap: chosen.isEmpty
                    ? null
                    : () => Navigator.pop(context, chosen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(L l, Palette p, ChangeSet chosen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.n(widget.set.affectedContacts, 'cfContactsOne', 'cfContactsN'),
            style: Type.display(p, size: 38),
          ),
          const SizedBox(height: 4),
          Text(
            intentLabel(l, widget.set.intent),
            style: Type.display(
              p,
              size: 18,
              italic: true,
            ).copyWith(color: p.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in ChangeKind.values)
                if (widget.set.count(k) > 0)
                  Tag(
                    '${kindLabel(l, k)} · ${chosen.count(k)}/${widget.set.count(k)}',
                    color: k == ChangeKind.delete ? p.accent : p.sage,
                  ),
            ],
          ),
          if (chosen.deletesFromSyncedAccount) ...[
            const SizedBox(height: 14),
            SyncedWarning(text: l.t('syncedDeleteWarn')),
          ],
          const SizedBox(height: 6),
          Text(
            l.t('backupFirst'),
            style: TextStyle(color: p.inkFaint, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _header(L l, Palette p, ChangeKind k) {
    final rows = _byKind[k]!;
    final all = rows.every(_on.contains);
    return SectionLabel(
      '${kindLabel(l, k)} · ${rows.length}',
      trailing: TextButton(
        onPressed: () => setState(() {
          if (all) {
            _on.removeAll(rows);
          } else {
            _on.addAll(rows);
          }
        }),
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          all ? l.t('clearSel') : l.t('selectAll'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _row(L l, Palette p, int i) {
    final c = widget.set.changes[i];
    final on = _on.contains(i);
    final fields = switch (c) {
      UpdateChange() => c.fields,
      MergeChange() => c.fields,
      _ => const <FieldChange>[],
    };
    final subtitle = switch (c) {
      CreateChange() => [
        c.after.primaryNumber,
        if (c.account != null && !c.account!.isLocal)
          accountLabel(l, c.account),
      ].where((e) => e.isNotEmpty).join(' · '),
      DeleteChange() => [
        c.before.primaryNumber,
        accountLabel(l, c.before.account),
      ].where((e) => e.isNotEmpty).join(' · '),
      MergeChange() => l.n(c.removed.length + 1, 'mergeIntoOne', 'mergeInto'),
      UpdateChange() => fields.map((f) => fieldLabel(l, f.field)).join(', '),
    };
    final open = _open.contains(i) || fields.length <= 2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => on ? _on.remove(i) : _on.add(i)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 20, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: on,
                    activeColor: p.accent,
                    onChanged: (v) =>
                        setState(() => v == true ? _on.add(i) : _on.remove(i)),
                  ),
                  Avatar(person: c.subject, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.subject.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: p.ink,
                            decoration: c.kind == ChangeKind.delete
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: p.accent,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: p.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (fields.length > 2)
                    IconButton(
                      tooltip: l.t('details'),
                      onPressed: () => setState(
                        () =>
                            _open.contains(i) ? _open.remove(i) : _open.add(i),
                      ),
                      icon: Icon(
                        _open.contains(i)
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: p.inkFaint,
                      ),
                    ),
                ],
              ),
              if (open && fields.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 96, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final f in fields) DiffLine(change: f)],
                  ),
                ),
              if (c is MergeChange)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 96, top: 2),
                  child: Text(
                    '${l.t('removes')}: ${c.removed.map((e) => e.displayName).join(', ')}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiffLine extends StatelessWidget {
  final FieldChange change;
  const DiffLine({super.key, required this.change});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${fieldLabel(l, change.field)}  ',
              style: Type.label(p).copyWith(fontSize: 10),
            ),
            TextSpan(
              text: fieldValue(l, change.field, change.before),
              style: TextStyle(
                color: p.inkFaint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            TextSpan(
              text: '  →  ',
              style: TextStyle(color: p.inkFaint),
            ),
            TextSpan(
              text: fieldValue(l, change.field, change.after),
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12.5, height: 1.35),
      ),
    );
  }
}
