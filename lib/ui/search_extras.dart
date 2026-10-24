import 'package:flutter/material.dart';

import '../l10n.dart';
import '../search/number_pattern.dart';
import '../state/contact_list.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import '../tags/tag_book.dart';
import 'widgets.dart';

class DigitModeChips extends StatelessWidget {
  final ContactList list;
  const DigitModeChips({super.key, required this.list});

  static const _labels = {
    DigitMode.anywhere: 'digitAnywhere',
    DigitMode.ends: 'digitEnds',
    DigitMode.starts: 'digitStarts',
    DigitMode.contains: 'digitContains',
  };

  @override
  Widget build(BuildContext context) {
    if (!NumberQuery.parse(list.query).digitsOnly) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final e in _labels.entries)
            ChoiceChip(
              key: ValueKey('digit-${e.key.name}'),
              label: Text(l.t(e.value)),
              selected: list.digitMode == e.key,
              onSelected: (_) => list.setDigitMode(e.key),
              selectedColor: p.accent.withValues(alpha: 0.18),
              side: BorderSide(color: p.hairline),
              showCheckmark: false,
            ),
        ],
      ),
    );
  }
}

Future<void> showSearchHelp(BuildContext context) {
  final l = L.of(context);
  final p = context.pal;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.sheet,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('searchHelpTitle'),
              style: TextStyle(
                color: p.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              l.t('searchHelpBody'),
              style: TextStyle(color: p.inkSoft, fontSize: 14.5, height: 1.8),
            ),
          ],
        ),
      ),
    ),
  );
}

class SearchHelpButton extends StatelessWidget {
  const SearchHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    return SizedBox(
      width: 48,
      height: 52,
      child: IconButton(
        key: const ValueKey('searchHelp'),
        tooltip: l.t('searchHelpTitle'),
        onPressed: () => showSearchHelp(context),
        icon: Icon(Icons.help_outline_rounded, size: 20, color: p.inkFaint),
      ),
    );
  }
}

class TagFilterRow extends StatelessWidget {
  final ContactList list;
  const TagFilterRow({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    List<String> names;
    try {
      names = [for (final t in context.watch<TagBook>().tags) t.name];
    } catch (_) {
      names = const [];
    }
    if (names.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        children: [
          for (final t in names) ...[
            Pill(
              key: ValueKey('tagfilter-$t'),
              label: t,
              icon: Icons.sell_outlined,
              active: list.tagFilter == t,
              onTap: () => list.setTagFilter(list.tagFilter == t ? null : t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

