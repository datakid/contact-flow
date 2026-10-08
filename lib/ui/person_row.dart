import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../search/fuzzy.dart';
import 'theme.dart';
import 'widgets.dart';

class RowMetrics {
  final double row;
  final double letter;
  const RowMetrics(this.row, this.letter);

  static RowMetrics of(BuildContext context) {
    final s = MediaQuery.textScalerOf(context);
    final text = s.scale(16) * 1.42 + 3 + s.scale(13.5) * 1.42;
    final row = 24 + (text > 44 ? text : 44) + 2;
    final letter = 30 + s.scale(26) * 1.3;
    return RowMetrics(row.ceilToDouble(), letter.ceilToDouble());
  }
}

class LetterHeader extends StatelessWidget {
  final String letter;
  final double height;
  const LetterHeader({super.key, required this.letter, required this.height});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 40, 6),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Row(
            children: [
              Text(
                letter,
                maxLines: 1,
                style: Type.display(p, size: 26).copyWith(color: p.accent),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: p.hairline)),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonRow extends StatelessWidget {
  final Person person;
  final Hit? hit;
  final bool selected;
  final bool selecting;
  final double height;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final bool showAccount;
  const PersonRow({
    super.key,
    required this.person,
    required this.hit,
    required this.selected,
    required this.selecting,
    required this.height,
    required this.onOpen,
    required this.onToggle,
    this.showAccount = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final l = L.of(context);
    final h = hit;
    final reason = switch (h?.reason) {
      'pinyin' => l.t('matchPinyin'),
      'fuzzy' => l.t('matchFuzzy'),
      'translit' => l.t('matchTranslit'),
      'details' => l.t('matchDetails'),
      'alias' => l.t('matchAlias', {'alias': h?.alias ?? ''}),
      _ => null,
    };
    final number = h?.matchedPhone ?? person.primaryNumber;
    final extra = person.phones.length > 1
        ? '  +${person.phones.length - 1}'
        : '';
    final secondary = number.isEmpty
        ? (person.emails.isNotEmpty ? person.emails.first : l.t('noNumberTag'))
        : '$number$extra';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (selecting) {
            HapticFeedback.selectionClick();
            onToggle();
          } else {
            onOpen();
          }
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onToggle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: height,
          color: selected
              ? p.accentSoft.withValues(alpha: 0.55)
              : Colors.transparent,
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 36, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle();
                },
                child: Avatar(person: person, selected: selected),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: HighlightText(
                            person.displayName,
                            ranges: h?.nameRanges ?? const [],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (person.starred) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 15, color: p.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Directionality(
                            textDirection: number.isEmpty
                                ? Directionality.of(context)
                                : TextDirection.ltr,
                            child: Text(
                              secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: h?.reason == 'phone'
                                    ? p.accent
                                    : (number.isEmpty ? p.inkFaint : p.inkSoft),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (person.org.isNotEmpty &&
                            person.name.isNotEmpty &&
                            reason == null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(color: p.inkFaint),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              person.org,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: p.inkFaint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (reason != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Tag(
                              reason,
                              color: h?.reason == 'alias' ? p.accent : p.sage,
                            ),
                          ),
                        ],
                      ],
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
}

class AlphabetScroller extends StatefulWidget {
  final List<String> letters;
  final ValueChanged<String> onLetter;
  const AlphabetScroller({
    super.key,
    required this.letters,
    required this.onLetter,
  });

  @override
  State<AlphabetScroller> createState() => _AlphabetScrollerState();
}

class _AlphabetScrollerState extends State<AlphabetScroller> {
  String? _active;

  void _at(double dy, double height) {
    if (widget.letters.isEmpty || height <= 0) return;
    final i = (dy / height * widget.letters.length).floor().clamp(
      0,
      widget.letters.length - 1,
    );
    final letter = widget.letters[i];
    if (letter != _active) {
      HapticFeedback.selectionClick();
      setState(() => _active = letter);
      widget.onLetter(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _at(d.localPosition.dy, h),
          onVerticalDragUpdate: (d) => _at(d.localPosition.dy, h),
          onVerticalDragEnd: (_) => setState(() => _active = null),
          onTapDown: (d) => _at(d.localPosition.dy, h),
          onTapUp: (_) => setState(() => _active = null),
          child: SizedBox(
            width: 28,
            child: Column(
              children: [
                for (final letter in widget.letters)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          letter,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: letter == _active ? p.accent : p.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
