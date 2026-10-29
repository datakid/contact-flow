import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../io/codec.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../search/fuzzy.dart';
import '../state/app_state.dart';
import 'batch_screen.dart';
import 'detail.dart';
import 'export_screen.dart';
import 'import_sheet.dart';
import 'settings_sheet.dart';
import 'search_extras.dart';
import 'theme.dart';
import 'widgets.dart';
import 'workspace.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTab;
  const HomeScreen({super.key, this.onTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.offset > 60;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = L.of(context);
    final p = context.pal;
    final list = s.visible;
    return PopScope(
      canPop: !s.selecting && !s.searching,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (s.selecting) {
          s.clearSelection();
        } else if (s.searching) {
          _search.clear();
          s.setQuery('');
          _focus.unfocus();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _header(s, l, p)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchHeader(
                      child: _searchBar(s, l, p),
                      elevated: _scrolled,
                      color: p.paper,
                      line: p.hairline,
                    ),
                  ),
                  if (s.people.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _empty(l, p),
                    )
                  else if (s.searching && list.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _noResults(s, l, p),
                    )
                  else ...[
                    if (!s.searching)
                      SliverToBoxAdapter(child: _sortRow(s, l, p)),
                    SliverToBoxAdapter(child: TagFilterRow(list: s)),
                    if (!s.searching && _focus.hasFocus)
                      SliverToBoxAdapter(
                        child: RecentSearchChips(
                          onPick: (q) {
                            _search.text = q;
                            _search.selection = TextSelection.collapsed(
                              offset: q.length,
                            );
                            s.setQuery(q);
                          },
                        ),
                      ),
                    if (s.searching)
                      SliverToBoxAdapter(child: SaveSearchButton(list: s)),
                    if (s.searching)
                      SliverToBoxAdapter(child: TagResultsButton(list: s)),
                    if (s.searching)
                      SliverToBoxAdapter(child: DigitModeChips(list: s)),
                    if (s.searching)
                      SliverToBoxAdapter(child: _resultRow(s, l, p, list)),
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final person = list[i];
                        final showLetter =
                            !s.searching &&
                            s.sort == SortMode.name &&
                            (i == 0 ||
                                s.letterFor(list[i - 1]) !=
                                    s.letterFor(person));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showLetter) _letter(s.letterFor(person), p),
                            _ContactRow(
                              key: ValueKey(person.id),
                              person: person,
                              hit: s.hitFor(person),
                              index: i,
                            ),
                          ],
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ],
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _dock(s, l, p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppState s, L l, Palette p) {
    final hasPeople = s.people.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onTab != null)
                Expanded(child: ScreenTitle(l.t('wsFiles')))
              else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l.t('appTitle').toUpperCase(),
                  style: AppText.label(p).copyWith(color: p.inkSoft),
                ),
                const Spacer(),
              ],
              if (hasPeople)
                IconButton(
                  onPressed: () => openBatchEditor(context, s.visible),
                  icon: Icon(Icons.table_rows_outlined, color: p.ink, size: 22),
                  tooltip: l.t('batchEdit'),
                ),
              IconButton(
                onPressed: () => showSettings(context),
                icon: Icon(Icons.tune_rounded, color: p.ink, size: 22),
                tooltip: l.t('settings'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              hasPeople ? l.t('library') : l.t('greeting'),
              key: ValueKey(hasPeople),
              style: AppText.display(p, size: 52),
 textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasPeople
                ? Wrap(
                    key: ValueKey('${s.people.length}-${s.phoneCount}'),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l.n(s.people.length, 'contacts_one', 'contacts_many'),
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('·', style: TextStyle(color: p.inkFaint)),
                      ),
                      Text(
                        l.n(s.phoneCount, 'numbers_one', 'numbers_many'),
                        style: TextStyle(
                          color: p.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Text(
                    l.t('tagline'),
                    key: const ValueKey('tag'),
                    style: AppText.display(
                      p,
                      size: 22,
                      italic: true,
                    ).copyWith(color: p.inkSoft),
                  ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _searchBar(AppState s, L l, Palette p) {
    final focused = _focus.hasFocus;
    final enabled = s.people.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _focus.requestFocus : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          decoration: BoxDecoration(
            color: p.sheet,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? p.accent.withValues(alpha: 0.7) : p.hairline,
              width: focused ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.search_rounded,
                size: 21,
                color: focused ? p.ink : p.inkFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _focus,
                  enabled: enabled,
                  onChanged: s.setQuery,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    s.rememberSearch(v);
                    _focus.unfocus();
                  },
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 15,
                    ),
                    hintText: l.t('search'),
                    hintMaxLines: 1,
                    hintStyle: TextStyle(
                      color: p.inkFaint,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (s.query.isNotEmpty)
                SizedBox(
                  width: 48,
                  height: 52,
                  child: IconButton(
                    key: const ValueKey('x'),
                    tooltip: l.t('clearSel'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _search.clear();
                      s.setQuery('');
                      _focus.requestFocus();
                    },
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: p.inkFaint,
                    ),
                  ),
                )
              else
                const SearchHelpButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortRow(AppState s, L l, Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        children: [
          Pill(
            label: l.t('sortName'),
            active: s.sort == SortMode.name,
            onTap: () => s.setSort(SortMode.name),
          ),
          const SizedBox(width: 8),
          Pill(
            label: l.t('sortRecent'),
            active: s.sort == SortMode.recent,
            onTap: () => s.setSort(SortMode.recent),
          ),
          const Spacer(),
          Flexible(
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (s.selected.length == s.people.length) {
                  s.clearSelection();
                } else {
                  s.selectAll(s.people);
                }
              },
              style: TextButton.styleFrom(foregroundColor: p.ink),
              child: Text(
                s.selected.length == s.people.length
                    ? l.t('clearSel')
                    : l.t('selectAll'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(AppState s, L l, Palette p, List<Person> list) {
    final all = list.every((x) => s.selected.contains(x.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.n(list.length, 'contacts_one', 'contacts_many'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(p),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (all) {
                s.deselect(list);
              } else {
                s.selectAll(list);
              }
            },
            style: TextButton.styleFrom(foregroundColor: p.accentText),
            icon: Icon(
              all ? Icons.remove_done_rounded : Icons.done_all_rounded,
              size: 18,
            ),
            label: Text(
              all ? l.t('clearSel') : l.t('selectResults'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _letter(String letter, Palette p) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(24, 22, 24, 6),
    child: Row(
      children: [
        Text(
          letter,
          style: AppText.display(p, size: 26).copyWith(color: p.accent),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: p.hairline)),
      ],
    ),
  );

  Widget _empty(L l, Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: SizedBox(
              height: 120,
              child: Stack(
                children: [
                  for (var i = 0; i < 4; i++)
                    PositionedDirectional(
                      start: i * 46.0,
                      top: i.isEven ? 10 : 34,
                      child: Transform.rotate(
                        angle: (i - 1.5) * 0.09,
                        child: FormatGlyph(
                          const [
                            Format.csv,
                            Format.vcf,
                            Format.xlsx,
                            Format.numbers,
                          ][i],
                          size: 58,
                          active: i == 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeSlideIn(
            index: 1,
            child: Text(l.t('emptyTitle'), style: AppText.display(p, size: 34)),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: Text(
              l.t('emptyBody'),
              style: TextStyle(
                fontSize: 15.5,
                height: 1.55,
                color: p.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResults(AppState s, L l, Palette p) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 160),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('noResults', {'q': s.query.trim()}),
          style: AppText.display(p, size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          l.t('noResultsSub'),
          style: TextStyle(color: p.inkSoft, fontSize: 15, height: 1.5),
        ),
      ],
    ),
  );

  Widget _dock(AppState s, L l, Palette p) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final sel = s.selected.length;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 16 + bottom),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              p.paper.withValues(alpha: 0),
              p.paper.withValues(alpha: 0.94),
              p.paper,
            ],
            stops: const [0, 0.38, 1],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(a),
              child: c,
            ),
          ),
          child: sel > 0
              ? Row(
                  key: const ValueKey('sel'),
                  children: [
                    RoundIcon(
                      icon: Icons.close_rounded,
                      tooltip: l.t('clearSel'),
                      onTap: s.clearSelection,
                    ),
                    const SizedBox(width: 10),
                    RoundIcon(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l.t('delete'),
                      onTap: () async {
                        final gone = await s.remove(s.selected.toList());
                        if (!mounted) return;
                        toast(
                          context,
                          l.t('removed', {'n': gone.length}),
                          action: l.t('undo'),
                          onAction: () => s.restore(gone),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    RoundIcon(
                      icon: Icons.table_rows_outlined,
                      tooltip: l.t('batchEdit'),
                      onTap: () => openBatchEditor(context, s.selectedPeople),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: l.t('export_n', {'n': sel}),
                        icon: Icons.north_east_rounded,
                        onTap: () => openExport(context, s.selectedPeople),
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('dock'),
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: l.t('import'),
                        icon: Icons.south_west_rounded,
                        onTap: () => showImport(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Pressable(
                        haptic: true,
                        onTap: s.people.isEmpty
                            ? null
                            : () => openExport(context, s.visible),
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.north_east_rounded,
                                color: p.onAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  l.t('export'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.onAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool elevated;
  final Color color;
  final Color line;
  _SearchHeader({
    required this.child,
    required this.elevated,
    required this.color,
    required this.line,
  });

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(
            color: elevated ? line : color.withValues(alpha: 0),
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SearchHeader old) => true;
}

class _ContactRow extends StatelessWidget {
  final Person person;
  final Hit? hit;
  final int index;
  const _ContactRow({
    super.key,
    required this.person,
    required this.hit,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final selected = context.select<AppState, bool>(
      (a) => a.selected.contains(person.id),
    );
    final selecting = context.select<AppState, bool>((a) => a.selecting);
    final p = context.pal;
    final l = L.of(context);
    final h = hit;
    final reason = switch (h?.reason) {
      'pinyin' => l.t('matchPinyin'),
      'fuzzy' => l.t('matchFuzzy'),
      'translit' => l.t('matchTranslit'),
      'details' => l.t('matchDetails'),
      'alias' => l.t('matchAlias', {'alias': h?.alias ?? ''}),
      _ => null,
    };
    final number = h?.matchedPhone ?? person.primaryNumber;
    final extra = person.phones.length > 1
        ? '  +${person.phones.length - 1}'
        : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (selecting) {
            HapticFeedback.selectionClick();
            s.toggle(person);
          } else {
            showDetail(context, person);
          }
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          s.toggle(person);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          color: selected
              ? p.accentSoft.withValues(alpha: 0.55)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  s.toggle(person);
                },
                child: Avatar(person: person, selected: selected),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightText(
                      person.displayName,
                      ranges: h?.nameRanges ?? const [],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '$number$extra',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: h?.reason == 'phone'
                                    ? p.accentText
                                    : p.inkSoft,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (person.org.isNotEmpty && reason == null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(color: p.inkFaint),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              person.org,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: p.inkFaint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (reason != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Tag(
                              reason,
                              color: h?.reason == 'alias'
                                  ? p.accentText
                                  : p.sageText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
