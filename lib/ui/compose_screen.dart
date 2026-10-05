import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/reach.dart';
import '../domain/templates.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../services/launcher.dart';
import '../state/app_state.dart';
import '../state/queue_state.dart';
import 'queue_screen.dart';
import 'reach_ui.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openCompose(BuildContext context, List<Person> people) {
  final l = L.of(context);
  if (people.isEmpty) {
    toast(context, l.t('nothingSelected'));
    return Future.value();
  }
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ComposeScreen(people: people)));
}

enum SendMode { oneByOne, group }

class ComposeScreen extends StatefulWidget {
  final List<Person> people;
  const ComposeScreen({super.key, required this.people});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _text = TextEditingController();
  Channel _channel = Channel.sms;
  SendMode _mode = SendMode.oneByOne;
  bool _whatsapp = true;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    ReachApps.available(context.read<Launcher>(), Channel.whatsapp).then((v) {
      if (mounted) setState(() => _whatsapp = v);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<Person> get _reachable =>
      widget.people.where((p) => p.hasNumber).toList();

  List<Person> get _missing =>
      widget.people.where((p) => !p.hasNumber).toList();

  void _insert(String token) {
    final sel = _text.selection;
    final t = _text.text;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(
      text: t.replaceRange(at, end, token),
      selection: TextSelection.collapsed(offset: at + token.length),
    );
  }

  Future<void> _start() async {
    final l = L.of(context);
    final launcher = context.read<Launcher>();
    final queue = context.read<QueueState>();
    final nav = Navigator.of(context);
    if (_reachable.isEmpty) {
      toast(context, l.t('noneReachable'));
      return;
    }
    var country = context.read<AppState>().country;
    if (_channel == Channel.whatsapp && country.isEmpty) {
      country = await askCountry(context) ?? '';
      if (!mounted || country.isEmpty) return;
    }
    if (_mode == SendMode.group && _channel == Channel.sms) {
      final numbers = [for (final p in _reachable) p.primaryNumber];
      final ok = await _confirmGroup(numbers.length);
      if (!ok || !mounted) return;
      final opened = await launcher.open(
        Reach.groupSms(numbers, text: _text.text.trim()),
      );
      if (!opened && mounted) toast(context, l.t('cantOpen'));
      return;
    }
    if (queue.active) {
      final replace = await _confirmReplace();
      if (!replace || !mounted) return;
    }
    await queue.start(
      _reachable,
      _text.text.trim(),
      channel: _channel,
      country: country,
    );
    if (!mounted) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const QueueScreen()));
  }

  Future<bool> _confirmReplace() async {
    final l = L.of(context);
    final p = context.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.t('replaceQueue'), style: Type.display(p, size: 26)),
        content: Text(l.t('replaceQueueBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l.t('startNew'),
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmGroup(int n) async {
    final l = L.of(context);
    final p = context.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.t('groupSmsTitle'), style: Type.display(p, size: 26)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('groupSeeEachOther'),
                style: TextStyle(color: p.inkSoft),
              ),
              if (n > Reach.groupWarnAt) ...[
                const SizedBox(height: 10),
                Text(
                  l.t('groupTooMany', {'n': n, 'max': Reach.groupWarnAt}),
                  style: TextStyle(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            key: const ValueKey('groupOpen'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l.t('openMessages'),
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final reachable = _reachable;
    final missing = _missing;
    final sample = reachable.isNotEmpty ? reachable.first : widget.people.first;
    final preview = MessageTemplate(_text.text).render(sample);
    final channels = [Channel.sms, if (_whatsapp) Channel.whatsapp];
    if (!channels.contains(_channel)) _channel = Channel.sms;
    final groupAllowed = _channel == Channel.sms;
    if (!groupAllowed) _mode = SendMode.oneByOne;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('compose'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                    child: Text(
                      l.n(reachable.length, 'recipientsOne', 'recipientsN'),
                      style: Type.display(p, size: 34),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Text(
                      l.t('neverSends'),
                      style: TextStyle(color: p.inkSoft, height: 1.5),
                    ),
                  ),
                  SectionLabel(l.t('channel')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in channels)
                          Pill(
                            key: ValueKey('ch-${c.name}'),
                            label: channelLabel(l, c),
                            icon: channelIcon(c),
                            active: _channel == c,
                            onTap: () => setState(() => _channel = c),
                          ),
                      ],
                    ),
                  ),
                  if (groupAllowed) ...[
                    SectionLabel(l.t('sendMode')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Pill(
                            label: l.t('oneByOne'),
                            active: _mode == SendMode.oneByOne,
                            onTap: () =>
                                setState(() => _mode = SendMode.oneByOne),
                          ),
                          Pill(
                            key: const ValueKey('mode-group'),
                            label: l.t('groupSms'),
                            active: _mode == SendMode.group,
                            onTap: () => setState(() => _mode = SendMode.group),
                          ),
                        ],
                      ),
                    ),
                    if (_mode == SendMode.group)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Text(
                          reachable.length > Reach.groupWarnAt
                              ? l.t('groupTooMany', {
                                  'n': reachable.length,
                                  'max': Reach.groupWarnAt,
                                })
                              : l.t('groupSeeEachOther'),
                          style: TextStyle(
                            color: p.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Text(
                        l.t('whatsappOneByOne'),
                        style: TextStyle(color: p.inkFaint, fontSize: 13),
                      ),
                    ),
                  SectionLabel(l.t('message')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: p.sheet,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.hairline, width: 1.2),
                      ),
                      child: TextField(
                        key: const ValueKey('composeText'),
                        controller: _text,
                        minLines: 4,
                        maxLines: 8,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: l.t('composeHint'),
                          hintStyle: TextStyle(color: p.inkFaint),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in MessageTemplate.tokens)
                          ActionChip(
                            label: Text(
                              l.t('tok_${t.substring(1, t.length - 1)}'),
                            ),
                            onPressed: () => _insert(t),
                          ),
                      ],
                    ),
                  ),
                  SectionLabel(l.t('preview')),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.accentSoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('previewFor', {'name': sample.displayName}),
                          style: Type.label(p),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview.isEmpty ? '—' : preview,
                          key: const ValueKey('composePreview'),
                          style: TextStyle(
                            color: p.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (missing.isNotEmpty) ...[
                    SectionLabel(
                      l.n(missing.length, 'noNumberOne', 'noNumberN'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        missing.map((e) => e.displayName).join(', '),
                        style: TextStyle(color: p.inkSoft, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const ValueKey('composeStart'),
                label: _mode == SendMode.group
                    ? l.t('openMessages')
                    : l.t('startQueue'),
                icon: Icons.arrow_forward_rounded,
                onTap: reachable.isEmpty ? null : _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
