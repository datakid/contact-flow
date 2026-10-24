import 'package:flutter/material.dart';

import '../l10n.dart';
import '../search/number_pattern.dart';
import '../state/contact_list.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import '../tags/tag_book.dart';
import 'widgets.dart';
import '../state/app_state.dart';

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

class RecentSearchChips extends StatelessWidget {
  final ValueChanged<String> onPick;
  const RecentSearchChips({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.recent.isEmpty && app.saved.isEmpty) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final q in app.saved)
            InputChip(
              key: ValueKey('saved-$q'),
              avatar: Icon(Icons.push_pin_rounded, size: 16, color: p.accent),
              label: Text(q, textDirection: TextDirection.ltr),
              onPressed: () => onPick(q),
              onDeleted: () => app.unsaveSearch(q),
              deleteButtonTooltipMessage: l.t('unsaveSearch'),
            ),
          for (final q in app.recent)
            ActionChip(
              key: ValueKey('recent-$q'),
              avatar: Icon(Icons.history_rounded, size: 16, color: p.inkFaint),
              label: Text(q, textDirection: TextDirection.ltr),
              onPressed: () => onPick(q),
            ),
          if (app.recent.isNotEmpty)
            TextButton(
              key: const ValueKey('recent-clear'),
              onPressed: app.forgetRecent,
              child: Text(l.t('clearRecent')),
            ),
        ],
      ),
    );
  }
}

class SaveSearchButton extends StatelessWidget {
  final ContactList list;
  const SaveSearchButton({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    final q = list.query.trim();
    if (q.isEmpty || !NumberQuery.parse(q).isPattern) {
      return const SizedBox.shrink();
    }
    final app = context.watch<AppState>();
    if (app.saved.contains(q)) return const SizedBox.shrink();
    final l = L.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: TextButton.icon(
          key: const ValueKey('save-search'),
          onPressed: () => app.saveSearch(q),
          icon: const Icon(Icons.push_pin_outlined, size: 18),
          label: Text(l.t('saveSearch')),
        ),
      ),
    );
  }
}

