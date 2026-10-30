import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/phone_book.dart';
import '../tags/group_import.dart';
import '../tags/tag_book.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showGroupTagsSheet(BuildContext context) {
  final book = context.read<PhoneBook>();
  final tags = context.read<TagBook>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        GroupTagsSheet(plans: GroupTagImport.plan(book.people), tags: tags),
  );
}

class GroupTagsSheet extends StatefulWidget {
  final List<GroupTagPlan> plans;
  final TagBook tags;
  const GroupTagsSheet({super.key, required this.plans, required this.tags});

  @override
  State<GroupTagsSheet> createState() => _GroupTagsSheetState();
}

class _GroupTagsSheetState extends State<GroupTagsSheet> {
  final Set<String> _picked = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final plans = widget.plans;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                l.t('groupTagsTitle'),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  l.t('groupTagsNone'),
                  key: const ValueKey('group-tags-none'),
                  style: TextStyle(color: p.inkSoft),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in plans)
                      CheckboxListTile(
                        key: ValueKey('group-tag-${g.name}'),
                        value: _picked.contains(g.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _picked.add(g.name);
                          } else {
                            _picked.remove(g.name);
                          }
                        }),
                        title: Text(g.name),
                        subtitle: Text(
                          l.t('groupTagsInfo', {
                            'n': g.contacts,
                            'm': g.numbers,
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            if (plans.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  key: const ValueKey('group-tags-apply'),
                  label: l.t('groupTagsApply', {'n': _picked.length}),
                  icon: Icons.sell_outlined,
                  busy: _busy,
                  onTap: _picked.isEmpty || _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final added = await GroupTagImport.apply(
                            widget.tags,
                            plans.where((g) => _picked.contains(g.name)),
                          );
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l.t('groupTagsDone', {'n': added})),
                            ),
                          );
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
