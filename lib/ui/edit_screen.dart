import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openEditor(BuildContext context, Person person) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _Editor(person: person),
    ),
  );
}

class _Row {
  final TextEditingController number;
  String label;
  _Row(String n, this.label) : number = TextEditingController(text: n);
}

class _Editor extends StatefulWidget {
  final Person person;
  const _Editor({required this.person});

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _name = TextEditingController(text: widget.person.name);
  late final _org = TextEditingController(text: widget.person.org);
  late final _email = TextEditingController(
    text: widget.person.emails.join(', '),
  );
  late final _note = TextEditingController(text: widget.person.note);
  late final List<_Row> _phones = widget.person.phones.isEmpty
      ? [_Row('', 'mobile')]
      : widget.person.phones.map((e) => _Row(e.number, e.label)).toList();

  static const _labels = ['mobile', 'work', 'home', 'main', 'fax', 'other'];

  @override
  void dispose() {
    for (final c in [
      _name,
      _org,
      _email,
      _note,
      ..._phones.map((e) => e.number),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = L.of(context);
    final phones = _phones
        .map((r) => PhoneEntry(r.number.text.trim(), r.label))
        .where((e) => Phones.digits(e.number).length >= 3)
        .toList();
    final emails = _email.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.contains('@'))
        .toList();
    if (_name.text.trim().isEmpty && phones.isEmpty && emails.isEmpty) {
      toast(context, l.t('needSomething'));
      return;
    }
    final p = widget.person
      ..name = _name.text.trim()
      ..org = _org.text.trim()
      ..note = _note.text.trim()
      ..phones = phones
      ..emails = emails;
    await context.read<AppState>().update(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.t('edit'),
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
                  _Field(controller: _name, label: l.t('name'), big: true),
                  _Field(controller: _org, label: l.t('company')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                    child: Text(
                      l.t('phone').toUpperCase(),
                      style: Type.label(p),
                    ),
                  ),
                  for (var i = 0; i < _phones.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          PopupMenuButton<String>(
                            initialValue: _phones[i].label,
                            onSelected: (v) =>
                                setState(() => _phones[i].label = v),
                            color: p.sheet,
                            itemBuilder: (_) => [
                              for (final x in _labels)
                                PopupMenuItem(
                                  value: x,
                                  child: Text(l.t('labels_$x')),
                                ),
                            ],
                            child: Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: p.sheet,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: p.hairline,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    l.t('labels_${_phones[i].label}'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: p.accent,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    size: 18,
                                    color: p.inkFaint,
                                  ),
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
                                  controller: _phones[i].number,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: p.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
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
                              onPressed: () => setState(
                                () => _phones.removeAt(i).number.dispose(),
                              ),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: p.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _phones.add(_Row('', 'mobile'))),
                      style: TextButton.styleFrom(foregroundColor: p.accent),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: Text(
                        l.t('addNumber'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _email,
                    label: l.t('email'),
                    keyboard: TextInputType.emailAddress,
                    ltr: true,
                  ),
                  _Field(controller: _note, label: l.t('note'), lines: 3),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: l.t('saveChanges'),
                icon: Icons.check_rounded,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      alignment: lines > 1 ? Alignment.topLeft : Alignment.centerLeft,
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
  final TextInputType? keyboard;
  final bool ltr;
  const _Field({
    required this.controller,
    required this.label,
    this.big = false,
    this.lines = 1,
    this.keyboard,
    this.ltr = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final field = TextField(
      controller: controller,
      maxLines: lines,
      minLines: lines,
      keyboardType: keyboard,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: big ? 18 : 15.5,
        color: p.ink,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
      ),
    );
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
            child: ltr
                ? Directionality(textDirection: TextDirection.ltr, child: field)
                : field,
          ),
        ],
      ),
    );
  }
}
