import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import 'edit_screen.dart';
import 'export_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showDetail(BuildContext context, Person person) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _Detail(person: person),
  );
}

class _Detail extends StatelessWidget {
  final Person person;
  const _Detail({required this.person});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final s = context.read<AppState>();
    void copy(String v) {
      Clipboard.setData(ClipboardData(text: v));
      HapticFeedback.selectionClick();
      toast(context, l.t('copied'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: IconButton(
                tooltip: l.t('edit'),
                icon: Icon(Icons.edit_outlined, color: p.ink, size: 21),
                onPressed: () {
                  Navigator.pop(context);
                  openEditor(context, person);
                },
              ),
            ),
          ),
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
          if (person.org.isNotEmpty && person.name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                person.org,
                textAlign: TextAlign.center,
                style: Type.display(
                  p,
                  size: 18,
                  italic: true,
                ).copyWith(color: p.inkSoft),
              ),
            ),
          const SizedBox(height: 22),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: p.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < person.phones.length; i++) ...[
                  if (i > 0)
                    Divider(indent: 18, endIndent: 18, color: p.hairline),
                  _Line(
                    label: l.t('labels_${person.phones[i].label}'),
                    value: person.phones[i].number,
                    ltr: true,
                    onTap: () => copy(person.phones[i].number),
                  ),
                ],
                for (final e in person.emails) ...[
                  Divider(indent: 18, endIndent: 18, color: p.hairline),
                  _Line(
                    label: l.t('email'),
                    value: e,
                    ltr: true,
                    onTap: () => copy(e),
                  ),
                ],
                if (person.note.isNotEmpty) ...[
                  Divider(indent: 18, endIndent: 18, color: p.hairline),
                  _Line(
                    label: l.t('note'),
                    value: person.note,
                    onTap: () => copy(person.note),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GhostButton(
                  label: l.t('delete'),
                  icon: Icons.delete_outline_rounded,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final m = ScaffoldMessenger.of(context);
                    final gone = await s.remove([person.id]);
                    nav.pop();
                    m.hideCurrentSnackBar();
                    m.showSnackBar(
                      SnackBar(
                        content: Text(l.t('removed', {'n': 1})),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                        action: SnackBarAction(
                          label: l.t('undo'),
                          onPressed: () => s.restore(gone),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: l.t('export'),
                    icon: Icons.north_east_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      openExport(context, [person]);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (person.source.isNotEmpty && person.source != 'sample')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                person.source == 'device' ? l.t('fromDevice') : person.source,
                textAlign: TextAlign.center,
                style: Type.label(p),
              ),
            ),
        ],
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
                        fontSize: 16.5,
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
