import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../batch/batch_ops.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

typedef BatchSave =
    Future<bool> Function(
      BuildContext context,
      List<Person> originals,
      List<Person> edited,
    );

Future<void> openBatchEditor(
  BuildContext context,
  List<Person> people, {
  BatchSave? onSave,
}) {
  final l = L.of(context);
  if (people.isEmpty) {
    toast(context, l.t('nothingToEdit'));
    return Future.value();
  }
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BatchScreen(people: people, onSave: onSave),
    ),
  );
}

enum _Col { name, phone1, phone2, company }

class BatchScreen extends StatefulWidget {
  final List<Person> people;
  final BatchSave? onSave;
  const BatchScreen({super.key, required this.people, this.onSave});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  late final Map<String, Person> _orig = {
    for (final p in widget.people) p.id: p,
  };
  late List<Person> _rows = widget.people.map(clonePerson).toList();
  final List<List<Person>> _history = [];
  final _hScroll = ScrollController();
  final _cell = TextEditingController();
  final _cellFocus = FocusNode();
  (String, _Col)? _editing;
  bool _saving = false;

  static const _w = {
    _Col.name: 190.0,
    _Col.phone1: 168.0,
    _Col.phone2: 168.0,
    _Col.company: 150.0,
  };
  static const _numW = 46.0;
  static const _rowH = 52.0;

  @override
  void initState() {
    super.initState();
    _cellFocus.addListener(() {
      if (!_cellFocus.hasFocus && mounted) _commitCell();
    });
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _cell.dispose();
    _cellFocus.dispose();
    super.dispose();
  }

  bool get _showPhone2 => _rows.any((p) => p.phones.length > 1);

  List<_Col> get _cols => [
    _Col.name,
    _Col.phone1,
    if (_showPhone2) _Col.phone2,
    _Col.company,
  ];

  List<Person> get _changed => [
    for (final r in _rows)
      if (!samePerson(_orig[r.id]!, r)) r,
  ];

  void _snapshot() {
    _history.add(_rows.map(clonePerson).toList());
    if (_history.length > 40) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    HapticFeedback.selectionClick();
    _cancelCell();
    setState(() => _rows = _history.removeLast());
  }

  String _value(Person p, _Col c) => switch (c) {
    _Col.name => p.name,
    _Col.phone1 => p.phones.isNotEmpty ? p.phones[0].number : '',
    _Col.phone2 => p.phones.length > 1 ? p.phones[1].number : '',
    _Col.company => p.org,
  };

  bool _cellChanged(Person p, _Col c) {
    final o = _orig[p.id];
    return o != null && _value(o, c) != _value(p, c);
  }

  void _startEdit(Person p, _Col c) {
    _commitCell();
    setState(() {
      _editing = (p.id, c);
      _cell.text = _value(p, c);
      _cell.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cell.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cellFocus.requestFocus();
    });
  }

  void _cancelCell() {
    if (_editing == null) return;
    setState(() => _editing = null);
  }

  void _commitCell() {
    final e = _editing;
    if (e == null) return;
    _editing = null;
    final i = _rows.indexWhere((r) => r.id == e.$1);
    if (i < 0) {
      setState(() {});
      return;
    }
    final row = _rows[i];
    final v = _cell.text.trim();
    if (v == _value(row, e.$2)) {
      setState(() {});
      return;
    }
    _snapshot();
    final next = clonePerson(row);
    switch (e.$2) {
      case _Col.name:
        next.name = v;
      case _Col.company:
        next.org = v;
      case _Col.phone1:
      case _Col.phone2:
        final k = e.$2 == _Col.phone1 ? 0 : 1;
        if (v.isEmpty) {
          if (k < next.phones.length) next.phones.removeAt(k);
        } else if (k < next.phones.length) {
          next.phones[k] = PhoneEntry(v, next.phones[k].label);
        } else {
          next.phones.add(PhoneEntry(v));
        }
    }
    setState(() => _rows[i] = next);
  }

  void _nextRow() {
    final e = _editing;
    if (e == null) return;
    final i = _rows.indexWhere((r) => r.id == e.$1);
    _commitCell();
    if (i >= 0 && i + 1 < _rows.length) {
      _startEdit(_rows[i + 1], e.$2);
    } else {
      _cellFocus.unfocus();
    }
  }

  Future<void> _applyOp(BatchOp op) async {
    _commitCell();
    final res = BatchOp.run(op, _rows);
    if (res.isEmpty) {
      toast(context, L.of(context).t('noChanges'));
      return;
    }
    _snapshot();
    final byId = {for (final (_, after) in res) after.id: after};
    setState(() {
      _rows = [for (final r in _rows) byId[r.id] ?? r];
    });
    HapticFeedback.mediumImpact();
    toast(context, L.of(context).n(res.length, 'opAppliedOne', 'opApplied'));
  }

  Future<void> _save() async {
    _commitCell();
    final l = L.of(context);
    final s = context.read<AppState>();
    final changed = _changed;
    if (changed.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final custom = widget.onSave;
    if (custom != null) {
      final originals = [for (final c in changed) _orig[c.id]!];
      final ok = await custom(context, originals, changed);
      if (!mounted) return;
      if (ok) {
        nav.pop();
      } else {
        setState(() => _saving = false);
      }
      return;
    }
    try {
      final before = await s.replaceMany(changed);
      nav.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.n(changed.length, 'updatedOne', 'updatedN')),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l.t('undo'),
            onPressed: () => s.replaceMany(before),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, friendlyError(e));
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    _commitCell();
    if (_changed.isEmpty) return true;
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.t('discardTitle')),
        content: Text(l.t('discardBody', {'n': _changed.length})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.t('keepEditing')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.t('discard')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final changed = _changed.length;
    final cols = _cols;
    final width = _numW + cols.fold<double>(0, (a, c) => a + _w[c]!);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await _confirmDiscard()) nav.pop();
            },
          ),
          title: Text(
            l.t('batchEdit'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: l.t('undo'),
              onPressed: _history.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Text(
                      l.n(_rows.length, 'contacts_one', 'contacts_many'),
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: changed == 0
                            ? Text(
                                l.t('tapCell'),
                                key: const ValueKey('hint'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.inkFaint,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Tag(
                                l.t('changedN', {'n': changed}),
                                key: ValueKey(changed),
                                color: p.accent,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: p.sheet,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.hairline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Scrollbar(
                    controller: _hScroll,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            _header(l, p, cols),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _rows.length,
                                itemExtent: _rowH,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.manual,
                                padding: const EdgeInsets.only(bottom: 12),
                                itemBuilder: (c, i) => _row(p, i, cols),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    GhostButton(
                      label: l.t('operations'),
                      icon: Icons.auto_fix_high_rounded,
                      onTap: _saving ? null : () => _openOps(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: changed == 0
                            ? l.t('done')
                            : l.n(changed, 'saveOne', 'saveN'),
                        icon: Icons.check_rounded,
                        busy: _saving,
                        onTap: _save,
                      ),
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

  Widget _header(L l, Palette p, List<_Col> cols) {
    String title(_Col c) => switch (c) {
      _Col.name => l.t('name'),
      _Col.phone1 => l.t('phone'),
      _Col.phone2 => '${l.t('phone')} 2',
      _Col.company => l.t('company'),
    };
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _numW,
            child: Center(child: Text('#', style: Type.label(p))),
          ),
          for (final c in cols)
            SizedBox(
              width: _w[c],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(title(c).toUpperCase(), style: Type.label(p)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(Palette p, int i, List<_Col> cols) {
    final r = _rows[i];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: p.hairline.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _numW,
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: p.inkFaint,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          for (final c in cols) _cellWidget(p, r, c),
        ],
      ),
    );
  }

  Widget _cellWidget(Palette p, Person r, _Col c) {
    final editing = _editing?.$1 == r.id && _editing?.$2 == c;
    final changed = _cellChanged(r, c);
    final isPhone = c == _Col.phone1 || c == _Col.phone2;
    final style = TextStyle(
      fontSize: 14.5,
      fontWeight: c == _Col.name ? FontWeight.w700 : FontWeight.w600,
      color: c == _Col.company ? p.inkSoft : p.ink,
      fontFeatures: isPhone ? const [FontFeature.tabularFigures()] : null,
    );
    Widget content;
    if (editing) {
      content = TextField(
        controller: _cell,
        focusNode: _cellFocus,
        style: style,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _nextRow(),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
      );
      if (isPhone) {
        content = Directionality(
          textDirection: TextDirection.ltr,
          child: content,
        );
      }
    } else {
      final v = _value(r, c);
      content = Text(
        v.isEmpty ? '—' : v,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: isPhone ? TextDirection.ltr : null,
        style: v.isEmpty ? style.copyWith(color: p.hairline) : style,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editing ? null : () => _startEdit(r, c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _w[c],
        height: _rowH,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: editing
              ? p.paper
              : changed
              ? p.accentSoft.withValues(alpha: 0.6)
              : Colors.transparent,
          border: editing ? Border.all(color: p.accent, width: 1.6) : null,
        ),
        child: content,
      ),
    );
  }

  void _openOps(BuildContext context) {
    _commitCell();
    _cellFocus.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => _OpsSheet(
        rows: _rows,
        onApply: (op) {
          Navigator.pop(c);
          _applyOp(op);
        },
      ),
    );
  }
}

class _OpDef {
  final String key;
  final IconData icon;
  final String group;
  const _OpDef(this.key, this.icon, this.group);
}

const _ops = [
  _OpDef('opReplaceName', Icons.find_replace_rounded, 'grpNames'),
  _OpDef('opAffix', Icons.text_fields_rounded, 'grpNames'),
  _OpDef('opPattern', Icons.format_list_numbered_rounded, 'grpNames'),
  _OpDef('opCase', Icons.text_format_rounded, 'grpNames'),
  _OpDef('opSwap', Icons.swap_horiz_rounded, 'grpNames'),
  _OpDef('opClean', Icons.cleaning_services_outlined, 'grpNames'),
  _OpDef('opAddAlias', Icons.badge_outlined, 'grpAliases'),
  _OpDef('opKeepAlias', Icons.bookmark_add_outlined, 'grpAliases'),
  _OpDef('opPromoteAlias', Icons.swap_vert_rounded, 'grpAliases'),
  _OpDef('opClearAliases', Icons.layers_clear_outlined, 'grpAliases'),
  _OpDef('opAddCc', Icons.public_rounded, 'grpNumbers'),
  _OpDef('opRemoveCc', Icons.public_off_rounded, 'grpNumbers'),
  _OpDef('opPrefix', Icons.dialpad_rounded, 'grpNumbers'),
  _OpDef('opFormat', Icons.pin_outlined, 'grpNumbers'),
  _OpDef('opDedupeNums', Icons.filter_1_rounded, 'grpNumbers'),
  _OpDef('opLabel', Icons.label_outline_rounded, 'grpNumbers'),
  _OpDef('opCompany', Icons.business_rounded, 'grpOther'),
  _OpDef('opNote', Icons.sticky_note_2_outlined, 'grpOther'),
];

class _OpsSheet extends StatelessWidget {
  final List<Person> rows;
  final void Function(BatchOp) onApply;
  const _OpsSheet({required this.rows, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final groups = <String, List<_OpDef>>{};
    for (final o in _ops) {
      (groups[o.group] ??= []).add(o);
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (c, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.only(
          bottom: 20 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(l.t('operations'), style: Type.display(p, size: 36)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: Text(
              l.t('opsSub', {'n': rows.length}),
              style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          for (final g in groups.entries) ...[
            SectionLabel(l.t(g.key)),
            for (final o in g.value)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Icon(o.icon, size: 20, color: p.ink),
                ),
                title: Text(
                  l.t(o.key),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  l.t('${o.key}Sub'),
                  style: TextStyle(color: p.inkSoft, fontSize: 12.5),
                ),
                onTap: () async {
                  final op = await showDialog<BatchOp>(
                    context: context,
                    builder: (_) => _OpDialog(kind: o.key, rows: rows),
                  );
                  if (op != null) onApply(op);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _OpDialog extends StatefulWidget {
  final String kind;
  final List<Person> rows;
  const _OpDialog({required this.kind, required this.rows});

  @override
  State<_OpDialog> createState() => _OpDialogState();
}

class _OpDialogState extends State<_OpDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _flag = false;
  CaseMode _case = CaseMode.title;
  NumFormat _fmt = NumFormat.e164;
  String _label = 'mobile';

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'opPattern') {
      _a.text = '{name}';
      _b.text = '1';
    }
    if (widget.kind == 'opNote') _flag = true;
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  BatchOp? get _op {
    final a = _a.text;
    final b = _b.text;
    return switch (widget.kind) {
      'opReplaceName' => a.isEmpty ? null : ReplaceInName(a, b),
      'opAffix' => AffixName(prefix: a, suffix: b),
      'opPattern' => TemplateName(
        a,
        start: int.tryParse(b.trim()) ?? 1,
        pad: _flag
            ? (widget.rows.length + (int.tryParse(b) ?? 1)).toString().length
            : 0,
        onlyEmpty: false,
      ),
      'opCase' => CaseName(_case),
      'opSwap' => const SwapName(),
      'opClean' => const CleanName(),
      'opAddAlias' => a.trim().isEmpty ? null : AddAlias(a),
      'opKeepAlias' => const KeepNameAsAlias(),
      'opPromoteAlias' => const PromoteAlias(),
      'opClearAliases' => const ClearAliases(),
      'opAddCc' => a.trim().isEmpty ? null : AddCountryCode(a),
      'opRemoveCc' => a.trim().isEmpty ? null : RemoveCountryCode(a),
      'opPrefix' => a.trim().isEmpty ? null : ReplaceInNumbers(a, b),
      'opFormat' => FormatNumbers(_fmt),
      'opDedupeNums' => const DedupeNumbers(),
      'opLabel' => LabelNumbers(_label),
      'opCompany' => SetCompany(a, onlyEmpty: _flag),
      'opNote' => a.trim().isEmpty ? null : SetNote(a, append: _flag),
      _ => null,
    };
  }

  bool get _numberOp => const {
    'opAddCc',
    'opRemoveCc',
    'opPrefix',
    'opFormat',
    'opDedupeNums',
    'opLabel',
  }.contains(widget.kind);

  String _show(Person p) {
    if (widget.kind == 'opCompany') return p.org.isEmpty ? '—' : p.org;
    if (widget.kind == 'opNote') return p.note.isEmpty ? '—' : p.note;
    if (widget.kind == 'opPromoteAlias') {
      final a = p.cleanAliases;
      return a.isEmpty ? p.name : '${p.name} · ${a.join(', ')}';
    }
    if (const {
      'opAddAlias',
      'opKeepAlias',
      'opClearAliases',
    }.contains(widget.kind)) {
      final a = p.cleanAliases;
      return a.isEmpty ? '—' : a.join(', ');
    }
    if (widget.kind == 'opLabel') {
      return p.phones.map((e) => e.label).join(', ');
    }
    if (_numberOp) {
      return p.phones.isEmpty ? '—' : p.phones.map((e) => e.number).join(', ');
    }
    return p.name.isEmpty ? '—' : p.name;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final op = _op;
    final res = op == null
        ? const <(Person, Person)>[]
        : BatchOp.run(op, widget.rows);
    return AlertDialog(
      title: Text(
        l.t(widget.kind),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._fields(l, p),
              const SizedBox(height: 14),
              _preview(l, p, res),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.t('cancel')),
        ),
        FilledButton(
          onPressed: res.isEmpty ? null : () => Navigator.pop(context, op),
          child: Text(
            res.isEmpty ? l.t('apply') : l.n(res.length, 'applyOne', 'applyN'),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? kb,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: kb,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        isDense: true,
      ),
    ),
  );

  Widget _check(String label) => CheckboxListTile(
    value: _flag,
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    onChanged: (v) => setState(() => _flag = v ?? false),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _choices<T>(List<(T, String)> items, T value, void Function(T) on) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (v, label) in items)
            Pill(
              label: label,
              active: v == value,
              onTap: () => setState(() => on(v)),
            ),
        ],
      );

  List<Widget> _fields(L l, Palette p) {
    switch (widget.kind) {
      case 'opReplaceName':
        return [
          _field(_a, l.t('find')),
          _field(_b, l.t('replaceWith'), hint: l.t('leaveEmptyRemove')),
        ];
      case 'opAffix':
        return [
          _field(_a, l.t('prefix'), hint: 'Dr. '),
          _field(_b, l.t('suffix'), hint: ' (Work)'),
        ];
      case 'opPattern':
        return [
          _field(_a, l.t('pattern'), hint: 'Client {n} {name}'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l.t('patternHelp'),
              style: TextStyle(fontSize: 12.5, color: p.inkSoft, height: 1.4),
            ),
          ),
          _field(_b, l.t('startAt'), kb: TextInputType.number),
          _check(l.t('padNumbers')),
        ];
      case 'opCase':
        return [
          _choices(
            [
              (CaseMode.title, 'Title Case'),
              (CaseMode.upper, 'UPPER'),
              (CaseMode.lower, 'lower'),
            ],
            _case,
            (v) => _case = v,
          ),
        ];
      case 'opAddCc':
        return [
          _field(_a, l.t('countryCode'), hint: '+971', kb: TextInputType.phone),
          Text(
            l.t('addCcHelp'),
            style: TextStyle(fontSize: 12.5, color: p.inkSoft, height: 1.4),
          ),
        ];
      case 'opRemoveCc':
        return [
          _field(_a, l.t('countryCode'), hint: '+971', kb: TextInputType.phone),
          Text(
            l.t('removeCcHelp'),
            style: TextStyle(fontSize: 12.5, color: p.inkSoft, height: 1.4),
          ),
        ];
      case 'opPrefix':
        return [
          _field(_a, l.t('oldPrefix'), hint: '050', kb: TextInputType.phone),
          _field(_b, l.t('newPrefix'), hint: '055', kb: TextInputType.phone),
        ];
      case 'opFormat':
        return [
          _choices(
            [
              (NumFormat.e164, '+14155550100'),
              (NumFormat.spaced, '+1 415 555 0100'),
              (NumFormat.digits, '14155550100'),
            ],
            _fmt,
            (v) => _fmt = v,
          ),
        ];
      case 'opLabel':
        return [
          _choices(
            [
              for (final x in const ['mobile', 'work', 'home', 'main', 'other'])
                (x, l.t('labels_$x')),
            ],
            _label,
            (v) => _label = v,
          ),
        ];
      case 'opCompany':
        return [
          _field(_a, l.t('company'), hint: l.t('leaveEmptyRemove')),
          _check(l.t('onlyEmpty')),
        ];
      case 'opNote':
        return [_field(_a, l.t('note')), _check(l.t('appendNote'))];
      case 'opAddAlias':
        return [
          _field(_a, l.t('alias'), hint: l.t('aliasHint')),
          Text(
            l.t('opAddAliasHelp'),
            style: TextStyle(fontSize: 12.5, color: p.inkSoft, height: 1.4),
          ),
        ];
      default:
        return [
          Text(
            l.t('${widget.kind}Sub'),
            style: TextStyle(color: p.inkSoft, height: 1.4),
          ),
        ];
    }
  }

  Widget _preview(L l, Palette p, List<(Person, Person)> res) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            res.isEmpty
                ? l.t('noChanges')
                : l.t('willChange', {'n': res.length}),
            style: Type.label(
              p,
            ).copyWith(color: res.isEmpty ? p.inkFaint : p.accent),
          ),
          for (final (b, a) in res.take(4)) ...[
            const SizedBox(height: 10),
            Text(
              _show(b),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkFaint,
                fontSize: 13,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(
              _show(a),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          if (res.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.t('andMore', {'n': res.length - 4}),
                style: TextStyle(color: p.inkSoft, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
