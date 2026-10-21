import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../tags/tag_book.dart';
import 'theme.dart';

class NumberTags extends StatelessWidget {
  final Person person;
  const NumberTags({super.key, required this.person});

  Future<void> _pick(
    BuildContext context,
    TagBook book,
    L l,
    String number,
  ) async {
    final have = book.tagIdsForNumber(number);
    final options = [
      for (final t in book.tags)
        if (!have.contains(t.id)) t,
    ];
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.t('tagPickTitle')),
        children: [
          for (final t in options)
            SimpleDialogOption(
              key: ValueKey('pick-${t.id}'),
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text(t.name),
            ),
          SimpleDialogOption(
            key: const ValueKey('pick-new'),
            onPressed: () => Navigator.pop(ctx, '\u0000new'),
            child: Text(l.t('tagNew')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == '\u0000new') {
      if (!context.mounted) return;
      final ctl = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: TextField(
            key: const ValueKey('tag-name'),
            controller: ctl,
            autofocus: true,
            decoration: InputDecoration(labelText: l.t('tagName')),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('cancel')),
            ),
            FilledButton(
              key: const ValueKey('tag-name-ok'),
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(l.t('save')),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      final tag = await book.create(name);
      await book.assign([tag.id], [number]);
      return;
    }
    await book.assign([choice], [number]);
  }

  @override
  Widget build(BuildContext context) {
    TagBook? book;
    try {
      book = context.watch<TagBook>();
    } catch (_) {
      book = null;
    }
    if (book == null || person.phones.isEmpty) return const SizedBox.shrink();
    final tags = book;
    final l = L.of(context);
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('tagsTitle'), style: Type.label(p)),
          for (final ph in person.phones) ...[
            const SizedBox(height: 10),
            Text(
              ph.number,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in tags.tagsForNumber(ph.number))
                  InputChip(
                    key: ValueKey('numtag-${ph.number}-${t.id}'),
                    label: Text(t.name),
                    backgroundColor: Color(t.colour).withValues(alpha: 0.2),
                    onDeleted: () => tags.unassign([t.id], [ph.number]),
                  ),
                ActionChip(
                  key: ValueKey('numtag-add-${ph.number}'),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l.t('tagAdd')),
                  onPressed: () => _pick(context, tags, l, ph.number),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
