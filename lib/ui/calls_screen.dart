import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calls/call_filter.dart';
import '../calls/call_models.dart';
import '../calls/call_source.dart';
import '../calls/calls_controller.dart';
import '../calls/ignore_book.dart';
import '../domain/change_set.dart';
import '../l10n.dart';
import '../state/phone_book.dart';
import '../tags/tag_book.dart';
import 'pipeline.dart';
import 'theme.dart';
import 'widgets.dart';
import 'workspace.dart';

class CallsScreen extends StatefulWidget {
  final ValueChanged<int> onTab;
  final CallSource? source;
  const CallsScreen({super.key, required this.onTab, this.source});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  CallsController? _c;
  final _pattern = TextEditingController();
  final _template = TextEditingController(text: '{tag} {last4}');

  @override
  void initState() {
    super.initState();
    final book = context.read<PhoneBook>();
    final ignore = context.read<IgnoreBook>();
    TagBook? tags;
    try {
      tags = context.read<TagBook>();
    } catch (_) {
      tags = null;
    }
    final c = CallsController(
      source: widget.source ?? ChannelCallSource(),
      contacts: () => book.people,
      refreshContacts: () => book.refresh(quiet: true),
      saveToPhone: (people) async {
        if (!mounted) return;
        await applyChanges(
          context,
          ChangeSet(ChangeIntent.create, [
            for (final p in people) CreateChange(p),
          ]),
          review: false,
        );
      },
      ignore: ignore,
      tags: tags,
    );
    c.addListener(_rebuild);
    _c = c;
    c.start();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_rebuild);
    _c?.dispose();
    _pattern.dispose();
    _template.dispose();
    super.dispose();
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Widget _chip(String label, bool on, VoidCallback tap, {Key? key}) {
    final p = context.pal;
    return FilterChip(
      key: key,
      label: Text(label),
      selected: on,
      onSelected: (_) => tap(),
      showCheckmark: false,
      selectedColor: p.accent.withValues(alpha: 0.18),
      side: BorderSide(color: p.hairline),
    );
  }

  void _toggleFilter(CallFilter Function(CallFilter) f) {
    final c = _c!;
    c.setFilter(f(c.filter));
  }

  Widget _filters(L l) {
    final c = _c!;
    final f = c.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _chip(
            l.t('callsF2'),
            f.minCalls >= 2,
            () => _toggleFilter(
              (x) => x.copyWith(minCalls: x.minCalls >= 2 ? 0 : 2),
            ),
            key: const ValueKey('calls-f2'),
          ),
          _chip(
            l.t('callsFTalked'),
            f.minTalkSec >= 30,
            () => _toggleFilter(
              (x) => x.copyWith(minTalkSec: x.minTalkSec >= 30 ? 0 : 30),
            ),
            key: const ValueKey('calls-ftalked'),
          ),
          _chip(
            l.t('callsFRecent'),
            f.lastDays == 30,
            () => _toggleFilter(
              (x) => x.lastDays == 30
                  ? x.copyWith(clearLastDays: true)
                  : x.copyWith(lastDays: 30),
            ),
            key: const ValueKey('calls-frecent'),
          ),
          _chip(
            l.t('callsFMissed'),
            f.missedOnly,
            () => _toggleFilter((x) => x.copyWith(missedOnly: !x.missedOnly)),
            key: const ValueKey('calls-fmissed'),
          ),
          _chip(
            l.t('callsFOutgoing'),
            f.outgoingOnly,
            () =>
                _toggleFilter((x) => x.copyWith(outgoingOnly: !x.outgoingOnly)),
            key: const ValueKey('calls-foutgoing'),
          ),
        ],
      ),
    );
  }

  Widget _row(CallGroup g, L l, Palette p) {
    final c = _c!;
    final on = c.selection.isIncluded(g.key);
    final out = c.selection.isExcluded(g.key);
    final title = g.cachedName.isNotEmpty ? g.cachedName : g.number;
    final tile = ListTile(
      key: ValueKey('call-${g.key}'),
      onTap: () => c.toggle(g),
      onLongPress: () => _detail(g, l),
      leading: Icon(
        on
            ? Icons.check_circle_rounded
            : (out ? Icons.block_rounded : Icons.circle_outlined),
        color: on ? p.accent : p.inkFaint,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: out ? p.inkFaint : p.ink,
          fontWeight: FontWeight.w700,
          decoration: out ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${l.n(g.count, 'calls_one', 'calls_many')} · '
        '${l.t('callsLast', {'d': _date(g.lastMs)})}',
        style: TextStyle(color: p.inkSoft, fontSize: 12.5),
      ),
      trailing: PopupMenuButton<String>(
        key: ValueKey('call-menu-${g.key}'),
        onSelected: (v) async {
          if (v == 'exclude') {
            c.exclude(g);
          } else if (v == 'never') {
            final undo = await c.ignoreNumbers([g]);
            if (!mounted) return;
            toast(
              context,
              l.t('callsNever'),
              action: l.t('undo'),
              onAction: undo,
            );
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'exclude', child: Text(l.t('callsExclude'))),
          PopupMenuItem(value: 'never', child: Text(l.t('callsNever'))),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('swipe-${g.key}'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          c.include(g);
        } else {
          c.exclude(g);
        }
        return false;
      },
      background: Container(
        color: p.accent.withValues(alpha: 0.18),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.check_circle_rounded, color: p.accent),
      ),
      secondaryBackground: Container(
        color: p.inkFaint.withValues(alpha: 0.18),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.block_rounded, color: p.inkSoft),
      ),
      child: tile,
    );
  }

  static String _clock(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_date(ms)} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _duration(int secs) {
    if (secs <= 0) return '0:00';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _typeKey(CallType t) => switch (t) {
    CallType.incoming => 'callIn',
    CallType.outgoing => 'callOut',
    CallType.missed => 'callMissed',
    CallType.rejected => 'callRejected',
    CallType.voicemail => 'callVoicemail',
    CallType.blocked => 'callBlocked',
    CallType.other => 'callOther',
  };

  Future<void> _detail(CallGroup g, L l) async {
    final c = _c!;
    final history = c.historyOf(g);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Text(
                  g.cachedName.isNotEmpty ? g.cachedName : g.number,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  '${l.n(g.count, 'calls_one', 'calls_many')} · '
                  '${l.t('callsTalked', {'t': _duration(g.talkSec)})}',
                ),
              ),
              Flexible(
                child: ListView.builder(
                  key: const ValueKey('call-history'),
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return ListTile(
                      dense: true,
                      title: Text(l.t(_typeKey(h.type))),
                      subtitle: Text(_clock(h.dateMs)),
                      trailing: Text(_duration(h.durationSec)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const ValueKey('detail-include'),
                      onPressed: () {
                        c.include(g);
                        Navigator.of(ctx).pop();
                      },
                      child: Text(l.t('callsInclude')),
                    ),
                    TextButton(
                      key: const ValueKey('detail-exclude'),
                      onPressed: () {
                        c.exclude(g);
                        Navigator.of(ctx).pop();
                      },
                      child: Text(l.t('callsExclude')),
                    ),
                    TextButton(
                      key: const ValueKey('detail-never'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await c.ignoreNumbers([g]);
                      },
                      child: Text(l.t('callsNever')),
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

  Future<void> _saveSheet(L l) async {
    final c = _c!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final names = c
              .drafts(_template.text)
              .take(3)
              .map((x) => x.name)
              .join(', ');
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('callsSaveTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('calls-template'),
                  controller: _template,
                  decoration: InputDecoration(labelText: l.t('callsTemplate')),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 8),
                Text(l.t('callsPreview', {'names': names})),
                const SizedBox(height: 16),
                PrimaryButton(
                  key: const ValueKey('calls-save'),
                  label: l.t('callsSaveN', {'n': c.selection.included.length}),
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () async {
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    nav.pop();
                    final r = await c.save(_template.text);
                    if (r.alreadyThere == 0) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l.t('callsSaved', {
                            'n': r.saved,
                            'm': r.alreadyThere,
                          }),
                        ),
                      ),
                    );
                  },
                ),
                if (c.tags != null)
                  TextButton(
                    key: const ValueKey('calls-tag-only'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _tagOnly(l);
                    },
                    child: Text(l.t('callsTagOnly')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _tagOnly(L l) async {
    final book = _c!.tags;
    if (book == null) return;
    final tag = await _pickTag(book, l);
    if (tag == null) return;
    await _c!.tagChosen([tag]);
  }

  Future<String?> _pickTag(TagBook book, L l) async {
    final tags = book.tags;
    if (tags.isEmpty) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        children: [
          for (final t in tags)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text(t.name),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final c = _c!;
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Expanded(child: ScreenTitle(l.t('wsCalls'))),
          if (c.phase == CallsPhase.ready)
            PopupMenuButton<String>(
              key: const ValueKey('calls-menu'),
              onSelected: (v) {
                switch (v) {
                  case 'all':
                    c.includeAllShown();
                  case 'invert':
                    c.invertShown();
                  case 'clear':
                    c.clearSelection();
                  case 'hidden':
                    c.setShowHidden(!c.showHidden);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'all', child: Text(l.t('callsSelectAll'))),
                PopupMenuItem(value: 'invert', child: Text(l.t('callsInvert'))),
                PopupMenuItem(value: 'clear', child: Text(l.t('callsClear'))),
                CheckedPopupMenuItem(
                  value: 'hidden',
                  checked: c.showHidden,
                  child: Text(l.t('callsShowHidden')),
                ),
              ],
            ),
        ],
      ),
    );
    Widget body;
    switch (c.phase) {
      case CallsPhase.idle:
      case CallsPhase.loading:
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l.t('callsLoading', {'n': c.progress})),
            ],
          ),
        );
      case CallsPhase.needPermission:
        body = Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l.t('callsAllowBody'), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('calls-allow'),
                label: l.t('callsAllow'),
                icon: Icons.call_rounded,
                onTap: c.grant,
              ),
            ],
          ),
        );
      case CallsPhase.error:
        body = Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${c.error}', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              PrimaryButton(
                label: l.t('tryAgain'),
                icon: Icons.refresh_rounded,
                onTap: c.load,
              ),
            ],
          ),
        );
      case CallsPhase.ready:
        body = Column(
          children: [
            _filters(l),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: TextField(
                key: const ValueKey('calls-pattern'),
                controller: _pattern,
                decoration: InputDecoration(
                  hintText: l.t('callsSearchHint'),
                  isDense: true,
                ),
                onChanged: (v) => c.setFilter(c.filter.copyWith(pattern: v)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  key: const ValueKey('calls-counter'),
                  c.selection.counterText(l),
                  style: TextStyle(color: p.inkSoft, fontSize: 12.5),
                ),
              ),
            ),
            Expanded(
              child: c.shown.isEmpty
                  ? Center(child: Text(l.t('callsEmpty')))
                  : ListView.builder(
                      itemCount: c.shown.length,
                      itemBuilder: (_, i) => _row(c.shown[i], l, p),
                    ),
            ),
            if (c.selection.included.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: PrimaryButton(
                    key: const ValueKey('calls-open-save'),
                    label: l.t('callsSaveN', {
                      'n': c.selection.included.length,
                    }),
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: () => _saveSheet(l),
                  ),
                ),
              ),
          ],
        );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            head,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
