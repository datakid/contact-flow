import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models/person.dart';
import 'theme.dart';

class AliasEditor extends StatefulWidget {
  final List<String> aliases;
  final String name;
  final ValueChanged<List<String>> onChanged;
  const AliasEditor({
    super.key,
    required this.aliases,
    required this.name,
    required this.onChanged,
  });

  @override
  State<AliasEditor> createState() => AliasEditorState();
}

class AliasEditorState extends State<AliasEditor> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> commitPending() {
    final pending = _input.text;
    if (pending.trim().isEmpty) return widget.aliases;
    final next = Aliases.union([
      widget.aliases,
      Aliases.parse(pending),
    ], name: widget.name);
    _input.clear();
    widget.onChanged(next);
    return next;
  }

  void _add() {
    final before = widget.aliases.length;
    final next = commitPending();
    if (next.length == before && _input.text.isEmpty) {
      HapticFeedback.selectionClick();
    }
    _focus.requestFocus();
  }

  void _remove(String a) {
    HapticFeedback.selectionClick();
    widget.onChanged([
      for (final x in widget.aliases)
        if (x != a) x,
    ]);
  }

  void _promote(String a) {
    HapticFeedback.selectionClick();
    widget.onChanged([
      a,
      for (final x in widget.aliases)
        if (x != a) x,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.aliases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.aliases.length; i++)
                  _Chip(
                    key: ValueKey('alias_${widget.aliases[i]}'),
                    text: widget.aliases[i],
                    primary: i == 0 && widget.aliases.length > 1,
                    onRemove: () => _remove(widget.aliases[i]),
                    onTap: i == 0 ? null : () => _promote(widget.aliases[i]),
                    removeLabel: l.t('remove'),
                  ),
              ],
            ),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
          decoration: BoxDecoration(
            color: p.sheet,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.hairline, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('aliasInput'),
                  controller: _input,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  onChanged: (v) {
                    if (RegExp(r'[,;،，]$').hasMatch(v)) _add();
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: p.ink,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: l.t('aliasHint'),
                    hintStyle: TextStyle(
                      color: p.inkFaint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('aliasAdd'),
                tooltip: l.t('addAlias'),
                onPressed: _add,
                icon: Icon(Icons.add_rounded, color: p.accent),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            widget.aliases.length > 1
                ? l.t('aliasOrderHelp')
                : l.t('aliasHelp'),
            style: TextStyle(fontSize: 12.5, color: p.inkFaint, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool primary;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final String removeLabel;
  const _Chip({
    super.key,
    required this.text,
    required this.primary,
    required this.onRemove,
    required this.onTap,
    required this.removeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: primary ? p.accentSoft : p.sheet,
      shape: StadiumBorder(
        side: BorderSide(
          color: primary ? p.accentSoft : p.hairline,
          width: 1.2,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: primary ? p.accent : p.ink,
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '$removeLabel · $text',
                  onPressed: onRemove,
                  icon: Icon(Icons.close_rounded, size: 16, color: p.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AliasLine extends StatelessWidget {
  final List<String> aliases;
  final TextAlign align;
  const AliasLine({
    super.key,
    required this.aliases,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    if (aliases.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 24, right: 24),
      child: Text(
        l.t('akaLine', {'names': aliases.join(' · ')}),
        key: const ValueKey('akaLine'),
        textAlign: align,
        style: Type.display(
          p,
          size: 18,
          italic: true,
        ).copyWith(color: p.inkSoft),
      ),
    );
  }
}
