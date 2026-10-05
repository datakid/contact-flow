import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/merger.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'pipeline.dart';
import 'theme.dart';
import 'widgets.dart';

List<DuplicateGroup> runFindDuplicates(List<Person> people) =>
    Merger.findDuplicates(people);

Future<List<DuplicateGroup>> findDuplicatesInBackground(List<Person> people) {
  if (kIsWeb || people.length < 800) {
    return Future.value(runFindDuplicates(people));
  }
  return compute(runFindDuplicates, people);
}

Future<void> openMerge(BuildContext context, {List<Person>? only}) {
  final l = L.of(context);
  if (only != null && only.length < 2) {
    toast(context, l.t('mergeNeedTwo'));
    return Future.value();
  }
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MergeScreen(only: only)));
}

String reasonLabel(L l, DuplicateGroup g) => [
  if (g.reasons.contains(DuplicateReason.sharedNumber)) l.t('dupSameNumber'),
  if (g.reasons.contains(DuplicateReason.sameName)) l.t('dupSameName'),
].join(' · ');

class MergeScreen extends StatefulWidget {
  final List<Person>? only;
  const MergeScreen({super.key, this.only});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  List<DuplicateGroup>? _groups;
  final Map<int, String> _keep = {};
  int _version = -1;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final book = context.read<PhoneBook>();
    final only = widget.only;
    List<DuplicateGroup> groups;
    if (only != null) {
      final ids = {for (final p in only) p.id};
      final live = book.people.where((p) => ids.contains(p.id)).toList();
      groups = live.length < 2 ? [] : [DuplicateGroup(live, const {}, '')];
    } else {
      groups = await findDuplicatesInBackground(book.people);
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _keep.clear();
      _version = book.people.length;
    });
  }

  Person _keepFor(int i) {
    final g = _groups![i];
    final id = _keep[i];
    return g.people.firstWhere(
      (p) => p.id == id,
      orElse: () => Merger.suggestKeep(g.people),
    );
  }

  Future<void> _mergeOne(int i) async {
    final g = _groups![i];
    final keep = _keepFor(i);
    final change = Merger.plan(keep, [
      for (final p in g.people)
        if (p.id != keep.id) p,
    ]);
    final r = await applyChanges(
      context,
      Merger.planAll([g], keepIds: {0: keep.id}),
    );
    if (r != null && mounted && change.removed.isNotEmpty) await _scan();
  }

  Future<void> _mergeAll() async {
    final groups = _groups!;
    final r = await applyChanges(
      context,
      Merger.planAll(
        groups,
        keepIds: {for (var i = 0; i < groups.length; i++) i: _keepFor(i).id},
      ),
    );
    if (r != null && mounted) await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.watch<PhoneBook>();
    if (_groups != null && book.people.length != _version && !book.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.t('duplicates'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: groups == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                          child: Text(
                            groups.isEmpty
                                ? l.t('noDuplicates')
                                : l.n(
                                    groups.length,
                                    'dupGroupsOne',
                                    'dupGroupsN',
                                  ),
                            style: Type.display(p, size: 34),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          child: Text(
                            l.t('mergeHelp'),
                            style: TextStyle(color: p.inkSoft, height: 1.5),
                          ),
                        ),
                        for (var i = 0; i < groups.length; i++)
                          _GroupCard(
                            key: ValueKey('dup-$i'),
                            group: groups[i],
                            keep: _keepFor(i),
                            onKeep: (id) => setState(() => _keep[i] = id),
                            onMerge: book.busy ? null : () => _mergeOne(i),
                          ),
                      ],
                    ),
                  ),
                  if (groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: PrimaryButton(
                        key: const ValueKey('mergeAll'),
                        label: l.n(groups.length, 'mergeAllOne', 'mergeAllN'),
                        icon: Icons.merge_rounded,
                        onTap: book.busy ? null : _mergeAll,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final DuplicateGroup group;
  final Person keep;
  final ValueChanged<String> onKeep;
  final VoidCallback? onMerge;
  const _GroupCard({
    super.key,
    required this.group,
    required this.keep,
    required this.onKeep,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final result = Merger.combine(keep, [
      for (final x in group.people)
        if (x.id != keep.id) x,
    ]);
    final reason = reasonLabel(l, group);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 6),
              child: Row(
                children: [
                  Tag(reason, color: p.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        group.evidence,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: l.rtl ? TextAlign.right : TextAlign.left,
                        style: TextStyle(color: p.inkFaint, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, bottom: 4),
            child: Text(l.t('chooseKeep').toUpperCase(), style: Type.label(p)),
          ),
          RadioGroup<String>(
            groupValue: keep.id,
            onChanged: (v) => v == null ? null : onKeep(v),
            child: Column(
              children: [
                for (final x in group.people)
                  InkWell(
                    onTap: () => onKeep(x.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<String>(value: x.id, activeColor: p.accent),
                          Avatar(person: x, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  x.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  [
                                    x.primaryNumber,
                                    if (x.phones.length > 1)
                                      '+${x.phones.length - 1}',
                                    accountLabel(l, x.account),
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.inkSoft,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 0, 4),
            child: Text(
              l.t('mergeResult', {
                'phones': result.phones.length,
                'emails': result.emails.length,
              }),
              style: TextStyle(color: p.inkSoft, fontSize: 13),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onMerge,
              style: TextButton.styleFrom(foregroundColor: p.accent),
              icon: const Icon(Icons.merge_rounded, size: 18),
              label: Text(
                l.t('merge'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
