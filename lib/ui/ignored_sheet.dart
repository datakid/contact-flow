import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calls/ignore_book.dart';
import '../l10n.dart';
import 'theme.dart';

Future<void> showIgnoredSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<IgnoreBook>.value(
        value: context.read<IgnoreBook>(),
        child: const IgnoredList(),
      ),
    );

class IgnoredList extends StatefulWidget {
  const IgnoredList({super.key});

  @override
  State<IgnoredList> createState() => _IgnoredListState();
}

class _IgnoredListState extends State<IgnoredList> {
  MapEntry<String, String>? _removed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.watch<IgnoreBook>();
    final entries = book.entries;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                l.t('ignoredTitle'),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  l.t('ignoredEmpty'),
                  key: const ValueKey('ignored-empty'),
                  style: TextStyle(color: p.inkSoft),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return ListTile(
                      key: ValueKey('ignored-${e.key}'),
                      title: Text(
                        e.value,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: p.ink),
                      ),
                      trailing: IconButton(
                        key: ValueKey('ignored-remove-${e.key}'),
                        tooltip: l.t('ignoredRemove'),
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () async {
                          await book.remove([e.key]);
                          if (!mounted) return;
                          setState(() => _removed = e);
                        },
                      ),
                    );
                  },
                ),
              ),
            if (_removed != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.t('ignoredRemoved'),
                        style: TextStyle(color: p.inkSoft),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('ignored-undo'),
                      onPressed: () async {
                        final r = _removed;
                        if (r == null) return;
                        await book.addKeys({r.key: r.value});
                        if (!mounted) return;
                        setState(() => _removed = null);
                      },
                      child: Text(l.t('undo')),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
