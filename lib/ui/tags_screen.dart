import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../tags/tag_book.dart';
import '../tags/tag_models.dart';
import 'theme.dart';
import 'widgets.dart' hide Tag;

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  Future<String?> _ask(BuildContext context, L l, {String initial = ''}) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
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
  }

  Future<void> _create(BuildContext context, TagBook book, L l) async {
    final name = await _ask(context, l);
    if (name == null || name.trim().isEmpty) return;
    await book.create(name);
  }

  Future<void> _rename(BuildContext context, TagBook book, L l, Tag t) async {
    final name = await _ask(context, l, initial: t.name);
    if (name == null || name.trim().isEmpty || name.trim() == t.name) return;
    final ok = await book.rename(t.id, name);
    if (!ok && context.mounted) toast(context, l.t('tagExists'));
  }

  Future<void> _recolour(BuildContext context, TagBook book, Tag t) async {
    final colour = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in TagBook.palette)
                InkWell(
                  key: ValueKey('tag-colour-$c'),
                  onTap: () => Navigator.pop(ctx, c),
                  child: CircleAvatar(backgroundColor: Color(c), radius: 18),
                ),
            ],
          ),
        ],
      ),
    );
    if (colour != null) await book.recolour(t.id, colour);
  }

  Future<void> _merge(BuildContext context, TagBook book, L l, Tag t) async {
    final others = [
      for (final o in book.tags)
        if (o.id != t.id) o,
    ];
    if (others.isEmpty) return;
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.t('tagMergeInto')),
        children: [
          for (final o in others)
            SimpleDialogOption(
              key: ValueKey('tag-merge-${o.id}'),
              onPressed: () => Navigator.pop(ctx, o.id),
              child: Text(o.name),
            ),
        ],
      ),
    );
    if (target == null) return;
    final undo = await book.merge(t.id, target);
    if (!context.mounted) return;
    toast(
      context,
      l.t('tagMerged'),
      action: l.t('undo'),
      onAction: () => book.undo(undo),
    );
  }

  Future<void> _delete(BuildContext context, TagBook book, L l, Tag t) async {
    final undo = await book.delete(t.id);
    if (!context.mounted) return;
    toast(
      context,
      l.t('tagDeleted'),
      action: l.t('undo'),
      onAction: () => book.undo(undo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.watch<TagBook>();
    final tags = book.tags;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: Text(l.t('tagsTitle'), style: AppText.display(p, size: 32)),
      ),
      floatingActionButton: tags.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('tag-new'),
              onPressed: () => _create(context, book, l),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide.none,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.t('tagNew')),
            ),
      body: tags.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.t('tagsEmpty'),
                      key: const ValueKey('tags-empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.inkSoft),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('tag-new'),
                      onPressed: () => _create(context, book, l),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.t('tagNew')),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              children: [
                for (final t in tags)
                  ListTile(
                    key: ValueKey('tag-${t.id}'),
                    leading: CircleAvatar(
                      backgroundColor: Color(t.colour),
                      radius: 10,
                    ),
                    title: Text(t.name),
                    subtitle: Text(l.t('tagNumbers', {'n': book.count(t.id)})),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('tag-menu-${t.id}'),
                      onSelected: (v) {
                        switch (v) {
                          case 'rename':
                            _rename(context, book, l, t);
                          case 'colour':
                            _recolour(context, book, t);
                          case 'merge':
                            _merge(context, book, l, t);
                          case 'delete':
                            _delete(context, book, l, t);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l.t('tagRename')),
                        ),
                        PopupMenuItem(
                          value: 'colour',
                          child: Text(l.t('tagColour')),
                        ),
                        PopupMenuItem(
                          value: 'merge',
                          child: Text(l.t('tagMerge')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l.t('tagDelete')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
