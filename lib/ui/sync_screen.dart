import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/matcher.dart';
import '../domain/sync.dart';
import '../io/jobs.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'pipeline.dart';
import 'theme.dart';
import 'widgets.dart';

Future<SyncPlan> planInBackground(SyncJob j) {
  if (kIsWeb || j.phone.length + j.rows.length < 1500) {
    return Future.value(runSyncPlan(j));
  }
  return compute(runSyncPlan, j);
}

Future<void> pickAndSync(BuildContext context) async {
  final l = L.of(context);
  FilePickerResult? res;
  try {
    res = await FilePicker.pickFiles(withData: true, type: FileType.any);
  } catch (_) {
    res = null;
  }
  final f = res?.files.firstOrNull;
  final bytes = f?.bytes;
  if (f == null || bytes == null || !context.mounted) return;
  try {
    final r = await decodeInBackground(DecodeJob(f.name, bytes));
    if (!context.mounted) return;
    if (r.people.isEmpty) {
      toast(context, l.t('nothingFound'));
      return;
    }
    await openSync(context, r.people);
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

Future<void> openSync(BuildContext context, List<Person> rows) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PhoneBook>(),
        child: SyncScreen(rows: rows),
      ),
    ),
  );
}

class SyncScreen extends StatefulWidget {
  final List<Person> rows;
  const SyncScreen({super.key, required this.rows});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  FieldPolicy _policy = FieldPolicy.fillEmpty;
  SyncPlan? _plan;
  bool _createNew = true;
  bool _applyUpdates = true;
  bool _showUnchanged = false;
  final Map<int, String> _conflicts = {};
  final Set<String> _delete = {};
  bool _showPhoneOnly = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final book = context.read<PhoneBook>();
    setState(() => _plan = null);
    final plan = await planInBackground(
      SyncJob(book.people, widget.rows, _policy),
    );
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _conflicts.removeWhere((k, _) => k >= plan.conflicts.length);
    });
  }

  Future<void> _continue() async {
    final plan = _plan!;
    final set = SyncPlanner.toChangeSet(
      plan,
      SyncChoices(
        skipFresh: _createNew
            ? const {}
            : {for (var i = 0; i < plan.fresh.length; i++) i},
        skipUpdates: _applyUpdates
            ? const {}
            : {for (var i = 0; i < plan.updates.length; i++) i},
        conflictTargets: _conflicts,
        deleteOnlyOnPhone: _delete,
      ),
    );
    final nav = Navigator.of(context);
    final r = await applyChanges(context, set);
    if (r != null && mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final plan = _plan;
    final busy = context.watch<PhoneBook>().busy;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('syncTitle'),
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
                      l.n(widget.rows.length, 'rowsOne', 'rowsN'),
                      style: Type.display(p, size: 34),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Text(
                      l.t('syncHelp'),
                      style: TextStyle(color: p.inkSoft, height: 1.5),
                    ),
                  ),
                  SectionLabel(l.t('policy')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in FieldPolicy.values)
                          Pill(
                            key: ValueKey('policy-${f.name}'),
                            label: l.t('policy_${f.name}'),
                            active: _policy == f,
                            onTap: () {
                              if (_policy == f) return;
                              _policy = f;
                              _run();
                            },
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      l.t('policy_${_policy.name}_sub'),
                      style: TextStyle(color: p.inkFaint, fontSize: 13),
                    ),
                  ),
                  if (plan == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._groups(plan, l, p),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const ValueKey('syncContinue'),
                label: l.t('reviewChanges'),
                icon: Icons.arrow_forward_rounded,
                onTap: plan == null || busy ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groups(SyncPlan plan, L l, Palette p) {
    Widget toggleTile(
      String title,
      int n,
      bool value,
      ValueChanged<bool> onChanged, {
      Key? key,
    }) => SwitchListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      value: value && n > 0,
      onChanged: n == 0 ? null : onChanged,
      title: Text(
        '$title · $n',
        style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
      ),
    );

    return [
      SectionLabel(l.t('syncGroups')),
      toggleTile(
        l.t('grpNew'),
        plan.fresh.length,
        _createNew,
        (v) => setState(() => _createNew = v),
        key: const ValueKey('grp-new'),
      ),
      for (final x in plan.fresh.take(_createNew ? 4 : 0))
        _personLine(x, p, sub: x.primaryNumber),
      if (plan.fresh.length > 4 && _createNew)
        _more(plan.fresh.length - 4, l, p),
      toggleTile(
        l.t('grpUpdate'),
        plan.updates.length,
        _applyUpdates,
        (v) => setState(() => _applyUpdates = v),
        key: const ValueKey('grp-update'),
      ),
      for (final u in plan.updates.take(_applyUpdates ? 6 : 0))
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${u.before.displayName} · ${l.t('match_${u.match.reason.name}')}',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
              ),
              for (final f in u.fields) DiffLine(change: f),
            ],
          ),
        ),
      if (plan.updates.length > 6 && _applyUpdates)
        _more(plan.updates.length - 6, l, p),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        onTap: () => setState(() => _showUnchanged = !_showUnchanged),
        title: Text(
          '${l.t('grpUnchanged')} · ${plan.unchanged.length}',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.inkSoft),
        ),
        trailing: Icon(
          _showUnchanged
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          color: p.inkFaint,
        ),
      ),
      if (_showUnchanged)
        for (final m in plan.unchanged) _personLine(m.target, p),
      if (plan.conflicts.isNotEmpty) ...[
        SectionLabel('${l.t('grpConflicts')} · ${plan.conflicts.length}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            l.t('conflictHelp'),
            style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.4),
          ),
        ),
        for (var i = 0; i < plan.conflicts.length; i++)
          _conflict(i, plan.conflicts[i], l, p),
      ],
      ListTile(
        key: const ValueKey('grp-phoneonly'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        onTap: () => setState(() => _showPhoneOnly = !_showPhoneOnly),
        title: Text(
          '${l.t('grpPhoneOnly')} · ${plan.onlyOnPhone.length}',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.inkSoft),
        ),
        subtitle: Text(
          _delete.isEmpty
              ? l.t('phoneOnlyKeep')
              : l.n(_delete.length, 'willDeleteOne', 'willDeleteN'),
          style: TextStyle(color: _delete.isEmpty ? p.inkFaint : p.accent),
        ),
        trailing: Icon(
          _showPhoneOnly
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          color: p.inkFaint,
        ),
      ),
      if (_showPhoneOnly)
        for (final x in plan.onlyOnPhone)
          CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            value: _delete.contains(x.id),
            activeColor: p.accent,
            onChanged: (v) => setState(
              () => v == true ? _delete.add(x.id) : _delete.remove(x.id),
            ),
            title: Text(
              x.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(l.t('deleteFromPhone')),
          ),
    ];
  }

  Widget _more(int n, L l, Palette p) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: Text(
      l.t('andMore', {'n': n}),
      style: TextStyle(color: p.inkFaint, fontSize: 13),
    ),
  );

  Widget _personLine(Person x, Palette p, {String sub = ''}) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 2, 24, 6),
    child: Row(
      children: [
        Avatar(person: x, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            sub.isEmpty ? x.displayName : '${x.displayName} · $sub',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _conflict(int i, Conflict c, L l, Palette p) {
    final chosen = _conflicts[i];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${c.row.displayName} · ${c.row.primaryNumber}',
            style: TextStyle(fontWeight: FontWeight.w800, color: p.ink),
          ),
          Text(
            l.t('conflict_${c.reason.name}'),
            style: TextStyle(color: p.accent, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(
                label: l.t('skipRow'),
                active: chosen == null,
                onTap: () => setState(() => _conflicts.remove(i)),
              ),
              for (final cand in c.candidates)
                Pill(
                  label: cand.displayName,
                  active: chosen == cand.id,
                  onTap: () => setState(() => _conflicts[i] = cand.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
