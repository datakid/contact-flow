import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/contact_source.dart';
import '../domain/planner.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import '../state/phone_book.dart';
import '../state/queue_state.dart';
import 'phone_actions.dart';
import 'phone_detail.dart';
import 'phone_edit.dart';
import 'person_row.dart';
import 'pipeline.dart';
import 'queue_screen.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';
import 'workspace.dart';

class PhoneHome extends StatefulWidget {
  final ValueChanged<int> onTab;
  const PhoneHome({super.key, required this.onTab});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _listStart = GlobalKey();
  bool _scrolled = false;
  Map<String, double> _letterOffsets = const {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.hasClients && _scroll.offset > 60;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = context.read<PhoneBook>();
      if (book.load == LoadState.idle) book.checkAccess();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(String letter) {
    final off = _letterOffsets[letter];
    final ctx = _listStart.currentContext;
    if (off == null || ctx == null || !_scroll.hasClients) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderSliver) return;
    final start = ro.constraints.precedingScrollExtent;
    final target = (start + off - 70).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final book = context.watch<PhoneBook>();
    final app = context.watch<AppState>();
    final l = L.of(context);
    final p = context.pal;
    final ready = book.granted && book.load == LoadState.ready;
    return PopScope(
      canPop: !book.selecting && !book.searching,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (book.selecting) {
          book.clearSelection();
        } else if (book.searching) {
          _search.clear();
          book.setQuery('');
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
                  SliverToBoxAdapter(child: _header(book, app, l, p)),
                  if (!ready)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _stateFor(book, l, p),
                    )
                  else ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedBar(
                        child: _searchBar(book, l, p),
                        elevated: _scrolled,
                        color: p.paper,
                        line: p.hairline,
                      ),
                    ),
                    SliverToBoxAdapter(child: _queueBanner(l, p)),
                    if (!book.searching)
                      SliverToBoxAdapter(child: _filters(book, l, p)),
                    if (book.searching || book.filtering)
                      SliverToBoxAdapter(child: _resultRow(book, l, p)),
                    ..._list(book, l, p),
                  ],
                ],
              ),
              if (ready) _scroller(book),
              if (ready)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _dock(book, l, p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scroller(PhoneBook book) {
    if (book.searching || book.sort != SortMode.name || !_scrolled) {
      return const SizedBox.shrink();
    }
    final letters = _letterOffsets.keys.toList();
    if (letters.length < 4) return const SizedBox.shrink();
    return PositionedDirectional(
      end: 4,
      top: 84,
      bottom: 110,
      child: AlphabetScroller(letters: letters, onLetter: _jumpTo),
    );
  }

  Widget _header(PhoneBook book, AppState app, L l, Palette p) {
    final ready = book.granted && book.load == LoadState.ready;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: WorkspaceSwitch(tab: 0, onChanged: widget.onTab),
                ),
              ),
              const Spacer(),
              if (ready)
                IconButton(
                  onPressed: () => openPhoneTools(context),
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    color: p.ink,
                    size: 22,
                  ),
                  tooltip: l.t('tools'),
                ),
              IconButton(
                onPressed: () => showSettings(context),
                icon: Icon(Icons.tune_rounded, color: p.ink, size: 22),
                tooltip: l.t('settings'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(l.t('phoneTitle'), style: Type.display(p, size: 52)),
          const SizedBox(height: 10),
          if (ready)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.n(book.people.length, 'contacts_one', 'contacts_many'),
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
                  l.n(book.accountCounts.length, 'accountsOne', 'accountsN'),
                  style: TextStyle(
                    color: p.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (book.isDemo) ...[
                  const SizedBox(width: 10),
                  Tag(l.t('demoTag'), color: p.accent),
                ],
              ],
            )
          else
            Text(
              l.t('phoneTagline'),
              style: Type.display(
                p,
                size: 22,
                italic: true,
              ).copyWith(color: p.inkSoft),
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _stateFor(PhoneBook book, L l, Palette p) {
    if (book.granted) {
      if (book.load == LoadState.failed) {
        return StateView(
          icon: Icons.error_outline_rounded,
          title: l.t('loadFailed'),
          body: book.error,
          actions: [
            PrimaryButton(
              label: l.t('tryAgain'),
              icon: Icons.refresh_rounded,
              onTap: book.refresh,
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(),
        ),
      );
    }
    final files = GhostButton(
      label: l.t('useFiles'),
      icon: Icons.folder_open_rounded,
      onTap: () => widget.onTab(1),
    );
    switch (book.access) {
      case Access.unsupported:
        return StateView(
          key: const ValueKey('state-unsupported'),
          icon: Icons.smartphone_rounded,
          title: l.t('phoneOnlyTitle'),
          body: l.t('phoneOnlyBody'),
          actions: [
            PrimaryButton(
              key: const ValueKey('startDemo'),
              label: l.t('tryDemo'),
              icon: Icons.play_arrow_rounded,
              onTap: book.startDemo,
            ),
            files,
          ],
        );
      case Access.denied:
        return StateView(
          key: const ValueKey('state-denied'),
          icon: Icons.person_off_outlined,
          title: l.t('deniedTitle'),
          body: l.t('deniedBody'),
          actions: [
            PrimaryButton(
              label: l.t('tryAgain'),
              icon: Icons.refresh_rounded,
              onTap: book.requestAccess,
            ),
            files,
          ],
        );
      case Access.blocked:
        return StateView(
          key: const ValueKey('state-blocked'),
          icon: Icons.lock_outline_rounded,
          title: l.t('blockedTitle'),
          body: l.t('blockedBody'),
          actions: [
            PrimaryButton(
              label: l.t('openSettings'),
              icon: Icons.settings_rounded,
              onTap: book.openSettings,
            ),
            GhostButton(
              label: l.t('checkAgain'),
              icon: Icons.refresh_rounded,
              onTap: book.checkAccess,
            ),
            files,
          ],
        );
      case Access.notAsked:
      case Access.granted:
        return StateView(
          key: const ValueKey('state-explain'),
          icon: Icons.contacts_rounded,
          title: l.t('explainTitle'),
          body: l.t('explainBody'),
          points: [l.t('explain1'), l.t('explain2'), l.t('explain3')],
          actions: [
            PrimaryButton(
              key: const ValueKey('allowAccess'),
              label: l.t('continueAllow'),
              icon: Icons.arrow_forward_rounded,
              onTap: book.requestAccess,
            ),
            files,
          ],
        );
    }
  }

  Widget _searchBar(PhoneBook book, L l, Palette p) {
    final focused = _focus.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
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
                  key: const ValueKey('phoneSearch'),
                  controller: _search,
                  focusNode: _focus,
                  onChanged: book.setQuery,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _focus.unfocus(),
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
              if (book.query.isNotEmpty)
                SizedBox(
                  width: 48,
                  height: 52,
                  child: IconButton(
                    tooltip: l.t('clearSel'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _search.clear();
                      book.setQuery('');
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
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _queueBanner(L l, Palette p) {
    final q = context.watch<QueueState>();
    final queue = q.queue;
    if (queue == null || !q.active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Pressable(
        key: const ValueKey('queueBanner'),
        onTap: () => openQueue(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: p.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.t('queueBanner', {
                    'done': queue.handled,
                    'total': queue.total,
                  }),
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                l.t('resume'),
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(PhoneBook book, L l, Palette p) {
    final accounts = book.accountCounts.keys.toList()..sort();
    final groups = book.allGroups.toList()..sort();
    Widget gap() => const SizedBox(width: 8);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        children: [
          Pill(
            label: l.t('sortName'),
            active: book.sort == SortMode.name,
            onTap: () => _setSort(book, SortMode.name),
          ),
          gap(),
          Pill(
            label: l.t('sortRecent'),
            active: book.sort == SortMode.recent,
            onTap: () => _setSort(book, SortMode.recent),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Container(width: 1, height: 22, color: p.hairline),
            ),
          ),
          Pill(
            key: const ValueKey('f-starred'),
            label: l.t('fStarred'),
            icon: Icons.star_rounded,
            active: book.filter == ListFilter.starred,
            onTap: () => _toggleFilter(book, ListFilter.starred),
          ),
          gap(),
          Pill(
            key: const ValueKey('f-nonumber'),
            label: l.t('fNoNumber'),
            active: book.filter == ListFilter.noNumber,
            onTap: () => _toggleFilter(book, ListFilter.noNumber),
          ),
          gap(),
          Pill(
            label: l.t('fNoName'),
            active: book.filter == ListFilter.noName,
            onTap: () => _toggleFilter(book, ListFilter.noName),
          ),
          if (accounts.length > 1)
            for (final a in accounts) ...[
              gap(),
              Pill(
                label:
                    '${accountLabel(l, book.accountFor(a))} · ${book.accountCounts[a]}',
                icon: Icons.account_circle_outlined,
                active: book.accountFilter == a,
                onTap: () => book.setFilter(
                  book.filter,
                  account: book.accountFilter == a ? null : a,
                  group: book.groupFilter,
                ),
              ),
            ],
          for (final g in groups) ...[
            gap(),
            Pill(
              label: g,
              icon: Icons.label_outline_rounded,
              active: book.groupFilter == g,
              onTap: () => book.setFilter(
                book.filter,
                account: book.accountFilter,
                group: book.groupFilter == g ? null : g,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _setSort(PhoneBook book, SortMode m) {
    book.sort = m;
    book.sortLang = context.read<AppState>().lang;
    book.setFilter(
      book.filter,
      account: book.accountFilter,
      group: book.groupFilter,
    );
  }

  void _toggleFilter(PhoneBook book, ListFilter f) => book.setFilter(
    book.filter == f ? ListFilter.all : f,
    account: book.accountFilter,
    group: book.groupFilter,
  );

  Widget _resultRow(PhoneBook book, L l, Palette p) {
    final list = book.visible;
    final all =
        list.isNotEmpty && list.every((x) => book.selected.contains(x.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.n(list.length, 'contacts_one', 'contacts_many'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label(p),
            ),
          ),
          if (book.filtering && !book.searching)
            TextButton(
              onPressed: book.clearFilters,
              style: TextButton.styleFrom(foregroundColor: p.inkSoft),
              child: Text(
                l.t('clearFilters'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (list.isNotEmpty)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (all) {
                  book.deselect(list);
                } else {
                  book.selectAll(list);
                }
              },
              style: TextButton.styleFrom(foregroundColor: p.accent),
              child: Text(
                all ? l.t('clearSel') : l.t('selectResults'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _list(PhoneBook book, L l, Palette p) {
    final list = book.visible;
    if (book.people.isEmpty) {
      _letterOffsets = const {};
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView(
            icon: Icons.person_add_alt_rounded,
            title: l.t('phoneEmptyTitle'),
            body: l.t('phoneEmptyBody'),
            actions: [
              PrimaryButton(
                label: l.t('newContact'),
                icon: Icons.add_rounded,
                onTap: () => openPhoneEditor(context),
              ),
            ],
          ),
        ),
      ];
    }
    if (list.isEmpty) {
      _letterOffsets = const {};
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 160),
            child: Text(
              book.searching
                  ? l.t('noResults', {'q': book.query.trim()})
                  : l.t('nothingMatches'),
              style: Type.display(p, size: 30),
            ),
          ),
        ),
      ];
    }
    final m = RowMetrics.of(context);
    final letters = !book.searching && book.sort == SortMode.name;
    final kinds = <int>[];
    final extents = <double>[];
    final offsets = <String, double>{};
    var y = 0.0;
    String? prev;
    for (var i = 0; i < list.length; i++) {
      if (letters) {
        final letter = book.letterFor(list[i]);
        if (letter != prev) {
          offsets.putIfAbsent(letter, () => y);
          kinds.add(-1 - i);
          extents.add(m.letter);
          y += m.letter;
          prev = letter;
        }
      }
      kinds.add(i);
      extents.add(m.row);
      y += m.row;
    }
    _letterOffsets = offsets;
    final selecting = book.selecting;
    return [
      SliverToBoxAdapter(key: _listStart, child: const SizedBox.shrink()),
      SliverVariedExtentList.builder(
        itemCount: kinds.length,
        itemExtentBuilder: (i, _) => i < extents.length ? extents[i] : null,
        itemBuilder: (c, i) {
          final k = kinds[i];
          if (k < 0) {
            final person = list[-1 - k];
            return LetterHeader(
              letter: book.letterFor(person),
              height: m.letter,
            );
          }
          final person = list[k];
          return PersonRow(
            key: ValueKey(person.id),
            person: person,
            hit: book.hitFor(person),
            selected: book.selected.contains(person.id),
            selecting: selecting,
            height: m.row,
            onOpen: () => openPhoneDetail(context, person),
            onToggle: () => book.toggle(person),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 140)),
    ];
  }

  Widget _dock(PhoneBook book, L l, Palette p) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final sel = book.selected.length;
    return Container(
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
        child: sel > 0
            ? Row(
                key: const ValueKey('sel'),
                children: [
                  RoundIcon(
                    icon: Icons.close_rounded,
                    tooltip: l.t('clearSel'),
                    onTap: book.clearSelection,
                  ),
                  const SizedBox(width: 10),
                  RoundIcon(
                    key: const ValueKey('bulkDelete'),
                    icon: Icons.delete_outline_rounded,
                    tooltip: l.t('delete'),
                    onTap: () async {
                      final r = await applyChanges(
                        context,
                        Planner.delete(book.selectedPeople),
                        review: false,
                      );
                      if (r != null) book.clearSelection();
                    },
                  ),
                  const SizedBox(width: 10),
                  RoundIcon(
                    icon: Icons.forum_outlined,
                    tooltip: l.t('message'),
                    onTap: () => startCompose(context, book.selectedPeople),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      key: const ValueKey('bulkMore'),
                      label: l.t('actionsN', {'n': sel}),
                      icon: Icons.more_horiz_rounded,
                      onTap: () =>
                          openSelectionActions(context, book.selectedPeople),
                    ),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('dock'),
                children: [
                  Expanded(
                    child: PrimaryButton(
                      key: const ValueKey('newContact'),
                      label: l.t('newContact'),
                      icon: Icons.add_rounded,
                      onTap: () => openPhoneEditor(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RoundIcon(
                    icon: Icons.auto_awesome_rounded,
                    tooltip: l.t('tools'),
                    accent: true,
                    onTap: () => openPhoneTools(context),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PinnedBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool elevated;
  final Color color;
  final Color line;
  _PinnedBar({
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
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
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
  bool shouldRebuild(_PinnedBar old) => true;
}

Person? livePerson(BuildContext context, String id) =>
    context.select<PhoneBook, Person?>((b) => b.byId(id));
