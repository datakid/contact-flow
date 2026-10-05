import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/planner.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../state/phone_book.dart';
import 'phone_edit.dart';
import 'pipeline.dart';
import 'reach_ui.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openPhoneDetail(BuildContext context, Person person) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => PhoneDetailScreen(id: person.id)));
}

class PhoneDetailScreen extends StatelessWidget {
  final String id;
  const PhoneDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final book = context.watch<PhoneBook>();
    final person = book.byId(id);
    if (person == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.t('contactGone'), style: Type.display(p, size: 28)),
          ),
        ),
      );
    }
    void copy(String v) {
      Clipboard.setData(ClipboardData(text: v));
      HapticFeedback.selectionClick();
      toast(context, l.t('copied'));
    }

    final lines = <Widget>[];
    void add(String label, String value, {bool ltr = false}) {
      if (value.trim().isEmpty) return;
      if (lines.isNotEmpty) {
        lines.add(Divider(indent: 18, endIndent: 18, color: p.hairline));
      }
      lines.add(
        _Line(label: label, value: value, ltr: ltr, onTap: () => copy(value)),
      );
    }

    for (final ph in person.phones) {
      add(l.t('labels_${ph.label}'), ph.number, ltr: true);
    }
    for (final e in person.emails) {
      add(l.t('email'), e, ltr: true);
    }
    add(l.t('company'), person.name.isEmpty ? '' : person.org);
    add(l.t('jobTitle'), person.jobTitle);
    add(l.t('groups'), person.groups.join(', '));
    add(l.t('note'), person.note);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('detailStar'),
            tooltip: person.starred ? l.t('unstar') : l.t('star'),
            icon: Icon(
              person.starred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: person.starred ? p.accent : p.ink,
            ),
            onPressed: book.busy
                ? null
                : () => applyChanges(
                    context,
                    Planner.star([person], !person.starred),
                    review: false,
                  ),
          ),
          IconButton(
            tooltip: l.t('shareVcard'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareContact(context, [person]),
          ),
          IconButton(
            key: const ValueKey('detailEdit'),
            tooltip: l.t('edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openPhoneEditor(context, person: person),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Center(child: Avatar(person: person, size: 84)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                person.displayName,
                textAlign: TextAlign.center,
                style: Type.display(p, size: 34),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    (person.account?.isSynced ?? false)
                        ? Icons.cloud_outlined
                        : Icons.smartphone_rounded,
                    size: 15,
                    color: p.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      accountLabel(l, person.account),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.label(p),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ReachBar(person: person),
            ),
            const SizedBox(height: 20),
            if (lines.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: p.sheet,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(children: lines),
              ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Flexible(
                    child: GhostButton(
                      key: const ValueKey('detailDelete'),
                      label: l.t('delete'),
                      icon: Icons.delete_outline_rounded,
                      onTap: book.busy
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final r = await applyChanges(
                                context,
                                Planner.delete([person]),
                                review: false,
                              );
                              if (r != null && r.ok > 0) nav.maybePop();
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: l.t('edit'),
                      icon: Icons.edit_outlined,
                      onTap: () => openPhoneEditor(context, person: person),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool ltr;
  final VoidCallback onTap;
  const _Line({
    required this.label,
    required this.value,
    required this.onTap,
    this.ltr = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: Type.label(p)),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: ltr
                        ? TextDirection.ltr
                        : Directionality.of(context),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 17, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
