import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal.dart';
import '../domain/change_set.dart';
import '../l10n.dart';
import '../services/file_out.dart';
import '../state/phone_book.dart';
import 'pipeline.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openHistory(BuildContext context) async {
  final book = context.read<PhoneBook>();
  await book.ensureJournal();
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatWhen(L l, DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return l.t('justNow');
  if (d.inHours < 1) return l.n(d.inMinutes, 'minAgoOne', 'minAgoN');
  if (d.inDays < 1) return l.n(d.inHours, 'hourAgoOne', 'hourAgoN');
  return l.n(d.inDays, 'dayAgoOne', 'dayAgoN');
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final book = context.watch<PhoneBook>();
    final l = L.of(context);
    final p = context.pal;
    final entries = book.journal.entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('history'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                l.t('historyBody'),
                style: TextStyle(color: p.inkSoft, height: 1.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                l.t('storageUsed', {
                  'size': formatBytes(book.journal.storageBytes),
                }),
                style: Type.label(p),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                child: Text(
                  l.t('historyEmpty'),
                  style: Type.display(p, size: 28),
                ),
              ),
            for (final e in entries) _EntryTile(entry: e),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.read<PhoneBook>();
    final names = entry.records.take(3).map((r) => r.label).join(', ');
    final more = entry.records.length > 3
        ? ' +${entry.records.length - 3}'
        : '';
    final counts = [
      for (final k in ChangeKind.values)
        if (entry.count(k) > 0) '${kindLabel(l, k)} ${entry.count(k)}',
      if (entry.failedCount > 0) l.n(entry.failedCount, 'failedOne', 'failedN'),
    ].join(' · ');
    final state = entry.undoneAt != null
        ? l.t('undoneTag')
        : entry.state == EntryState.cancelled
        ? l.t('stoppedTag')
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  intentLabel(l, entry.intent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: p.ink,
                  ),
                ),
              ),
              if (state != null) ...[Tag(state), const SizedBox(width: 6)],
              Text(
                formatWhen(l, entry.time, book.journal.clock()),
                style: TextStyle(color: p.inkFaint, fontSize: 12.5),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$names$more',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600),
          ),
          if (counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                counts,
                style: TextStyle(color: p.inkFaint, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (entry.canUndo)
                TextButton.icon(
                  key: ValueKey('undo-${entry.id}'),
                  onPressed: book.busy
                      ? null
                      : () async {
                          final plan = book.undoPlan(entry);
                          if (plan.isEmpty) {
                            toast(context, l.t('nothingToUndo'));
                            return;
                          }
                          await applyChanges(
                            context,
                            plan,
                            review: plan.length > 1,
                            undoOf: entry.id,
                          );
                        },
                  style: TextButton.styleFrom(foregroundColor: p.accent),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(
                    l.t('undo'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (entry.backupContacts > 0)
                TextButton.icon(
                  onPressed: () => shareBytes(
                    utf8.encode(entry.backupVcf),
                    'contact-flow-backup-${entry.id}.vcf',
                    'text/vcard',
                  ),
                  style: TextButton.styleFrom(foregroundColor: p.ink),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(
                    l.t('shareBackup'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              TextButton.icon(
                onPressed: () => book.deleteEntry(entry.id),
                style: TextButton.styleFrom(foregroundColor: p.inkSoft),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(
                  l.t('delete'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
