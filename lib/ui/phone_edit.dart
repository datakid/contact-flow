import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/planner.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'alias_editor.dart';
import 'pipeline.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openPhoneEditor(BuildContext context, {Person? person}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhoneEditScreen(person: person),
    ),
  );
}

class _PhoneRow {
  final TextEditingController number;
  String label;
  _PhoneRow(String n, this.label) : number = TextEditingController(text: n);
}

class PhoneEditScreen extends StatefulWidget {
  final Person? person;
  const PhoneEditScreen({super.key, this.person});

  @override
  State<PhoneEditScreen> createState() => _PhoneEditScreenState();
}

class _PhoneEditScreenState extends State<PhoneEditScreen> {
  late final Person _base = widget.person ?? Person(name: '');
  late final _name = TextEditingController(text: _base.name);
  late final _org = TextEditingController(text: _base.org);
  late final _job = TextEditingController(text: _base.jobTitle);
  late final _note = TextEditingController(text: _base.note);
  late final _group = TextEditingController();
  late final List<TextEditingController> _emails = _base.emails.isEmpty
      ? [TextEditingController()]
      : _base.emails.map((e) => TextEditingController(text: e)).toList();
  late final List<_PhoneRow> _phones = _base.phones.isEmpty
      ? [_PhoneRow('', 'mobile')]
      : _base.phones.map((e) => _PhoneRow(e.number, e.label)).toList();
  late final Set<String> _groups = {..._base.groups};
  late List<String> _aliases = _base.cleanAliases;
  final _aliasKey = GlobalKey<AliasEditorState>();
  late bool _starred = _base.starred;
  String? _accountKey;
  bool _saving = false;

  bool get _creating => widget.person == null;

  static const _labels = ['mobile', 'work', 'home', 'main', 'fax', 'other'];

  @override
  void dispose() {
    for (final c in [
      _name,
      _org,
      _job,
      _note,
      _group,
      ..._emails,
      ..._phones.map((e) => e.number),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Person _draft() {
    final out = _base.copy();
    out.name = _name.text.trim();
    out.org = _org.text.trim();
    out.jobTitle = _job.text.trim();
    out.note = _note.text.trim();
    out.phones = _phones
        .map((r) => PhoneEntry(r.number.text.trim(), r.label))
        .where((e) => Phones.digits(e.number).length >= 3)
        .toList();
    out.emails = _emails
        .map((e) => e.text.trim())
        .where((e) => e.contains('@'))
        .toList();
    out.starred = _starred;
    out.groups = _groups.toList()..sort();
    out.aliases = Aliases.clean(_aliases, name: out.name);
    return out;
  }

  Future<void> _save() async {
    final l = L.of(context);
    final book = context.read<PhoneBook>();
    final pending = _aliasKey.currentState?.commitPending();
    if (pending != null) _aliases = pending;
    final d = _draft();
    if (!d.hasName && d.phones.isEmpty && d.emails.isEmpty) {
      toast(context, l.t('needSomething'));
      return;
    }
    final nav = Navigator.of(context);
    if (!_creating && sameContentOf(widget.person!, d)) {
      nav.pop();
      return;
    }
    setState(() => _saving = true);
    final set = _creating
        ? Planner.create(
            d,
            account: _accountKey == null ? null : book.accountFor(_accountKey!),
          )
        : Planner.edit(widget.person!, d);
    final r = await applyChanges(context, set, review: false);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null && r.ok > 0) {
      nav.pop();
    } else if (r != null && r.failed > 0) {
      toast(context, l.t('saveFailed', {'why': r.entry.records.first.error}));
    }
  }

  static bool sameContentOf(Person a, Person b) => Planner.edit(a, b).isEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.watch<PhoneBook>();
    final accounts = <String>{
      for (final a in book.accounts) a.key,
      ...book.accountCounts.keys,
    }.toList();
    _accountKey ??= _creating && accounts.isNotEmpty
        ? (accounts.firstWhere(
            (k) => book.accountFor(k).isGoogle,
            orElse: () => accounts.first,
          ))
        : null;
    final allGroups = {...book.allGroups, ..._groups}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.t('cancel'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _creating ? l.t('newContact') : l.t('edit'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _starred ? l.t('unstar') : l.t('star'),
            onPressed: () => setState(() => _starred = !_starred),
            icon: Icon(
              _starred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _starred ? p.accent : p.ink,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _name,
                      builder: (_, _) =>
                          Avatar(person: Person(name: _name.text), size: 76),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Field(
                    key: const ValueKey('editName'),
                    controller: _name,
                    label: l.t('name'),
                    big: true,
                  ),
                  _Field(controller: _org, label: l.t('company')),
                  _Field(controller: _job, label: l.t('jobTitle')),
                  _label(l.t('phone'), p),
                  for (var i = 0; i < _phones.length; i++) _phoneRow(i, l, p),
                  _addButton(
                    l.t('addNumber'),
                    p,
                    () => setState(() => _phones.add(_PhoneRow('', 'mobile'))),
                  ),
                  _label(l.t('email'), p),
                  for (var i = 0; i < _emails.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Box(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: _input(
                                  _emails[i],
                                  p,
                                  keyboard: TextInputType.emailAddress,
                                ),
                              ),
                            ),
                          ),
                          if (_emails.length > 1)
                            IconButton(
                              tooltip: l.t('remove'),
                              onPressed: () =>
                                  setState(() => _emails.removeAt(i).dispose()),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: p.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  _addButton(
                    l.t('addEmail'),
                    p,
                    () => setState(() => _emails.add(TextEditingController())),
                  ),
                  _label(l.t('aliases'), p),
                  AnimatedBuilder(
                    animation: _name,
                    builder: (_, _) => AliasEditor(
                      key: _aliasKey,
                      aliases: _aliases,
                      name: _name.text,
                      onChanged: (v) => setState(() => _aliases = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Field(controller: _note, label: l.t('note'), lines: 3),
                  _label(l.t('groups'), p),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in allGroups)
                        Pill(
                          label: g,
                          active: _groups.contains(g),
                          onTap: () => setState(
                            () => _groups.contains(g)
                                ? _groups.remove(g)
                                : _groups.add(g),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Box(
                    child: Row(
                      children: [
                        Expanded(
                          child: _input(
                            _group,
                            p,
                            hint: l.t('newGroup'),
                            onSubmit: _addGroup,
                          ),
                        ),
                        IconButton(
                          tooltip: l.t('addGroup'),
                          onPressed: () => _addGroup(_group.text),
                          icon: Icon(Icons.add_rounded, color: p.accent),
                        ),
                      ],
                    ),
                  ),
                  if (_creating && accounts.length > 1) ...[
                    _label(l.t('saveTo'), p),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final k in accounts)
                          Pill(
                            label: accountLabel(l, book.accountFor(k)),
                            icon: Icons.account_circle_outlined,
                            active: _accountKey == k,
                            onTap: () => setState(() => _accountKey = k),
                          ),
                      ],
                    ),
                  ],
                  if (!_creating)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        '${l.t('savedIn')}: ${accountLabel(l, _base.account)}',
                        style: Type.label(p),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const ValueKey('editSave'),
                label: _creating ? l.t('createContact') : l.t('saveChanges'),
                icon: Icons.check_rounded,
                busy: _saving,
                onTap: book.busy ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addGroup(String v) {
    final g = v.trim();
    if (g.isEmpty) return;
    setState(() {
      _groups.add(g);
      _group.clear();
    });
  }

  Widget _label(String text, Palette p, {double top = 20}) => Padding(
    padding: EdgeInsets.fromLTRB(4, top, 4, 10),
    child: Text(text.toUpperCase(), style: Type.label(p)),
  );

  Widget _addButton(String label, Palette p, VoidCallback onTap) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: p.accent),
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  Widget _input(
    TextEditingController c,
    Palette p, {
    TextInputType? keyboard,
    String? hint,
    ValueChanged<String>? onSubmit,
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    onSubmitted: onSubmit,
    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.ink),
    decoration: InputDecoration(
      border: InputBorder.none,
      isCollapsed: true,
      hintText: hint,
      hintStyle: TextStyle(color: p.inkFaint, fontWeight: FontWeight.w500),
    ),
  );

  Widget _phoneRow(int i, L l, Palette p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        PopupMenuButton<String>(
          initialValue: _phones[i].label,
          onSelected: (v) => setState(() => _phones[i].label = v),
          color: p.sheet,
          itemBuilder: (_) => [
            for (final x in _labels)
              PopupMenuItem(value: x, child: Text(l.t('labels_$x'))),
          ],
          child: Container(
            height: 54,
            constraints: const BoxConstraints(maxWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: p.sheet,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.hairline, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l.t('labels_${_phones[i].label}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 18, color: p.inkFaint),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Box(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                key: ValueKey('editPhone$i'),
                controller: _phones[i].number,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: p.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
        ),
        if (_phones.length > 1)
          IconButton(
            tooltip: l.t('remove'),
            onPressed: () =>
                setState(() => _phones.removeAt(i).number.dispose()),
            icon: Icon(Icons.remove_circle_outline_rounded, color: p.inkFaint),
          ),
      ],
    ),
  );
}

class _Box extends StatelessWidget {
  final Widget child;
  final int lines;
  const _Box({required this.child, this.lines = 1});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      constraints: BoxConstraints(minHeight: lines > 1 ? 90 : 54),
      alignment: lines > 1
          ? AlignmentDirectional.topStart
          : AlignmentDirectional.centerStart,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: lines > 1 ? 14 : 0,
      ),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline, width: 1.2),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool big;
  final int lines;
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    this.big = false,
    this.lines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(label.toUpperCase(), style: Type.label(p)),
          ),
          _Box(
            lines: lines,
            child: TextField(
              controller: controller,
              maxLines: lines,
              minLines: lines,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: big ? 18 : 15.5,
                color: p.ink,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
