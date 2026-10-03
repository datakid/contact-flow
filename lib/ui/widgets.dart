import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../io/codec.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../search/fold.dart';
import 'theme.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _set(false);
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final Person person;
  final double size;
  final bool selected;
  const Avatar({
    super.key,
    required this.person,
    this.size = 44,
    this.selected = false,
  });

  static String initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '·';
    if (Fold.hasCjk(t)) {
      final r = t.runes.where(Fold.isCjk).toList();
      if (r.isEmpty) return String.fromCharCode(t.runes.first);
      return String.fromCharCode(r.length >= 3 ? r[1] : r.first);
    }
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (Fold.hasArabic(t)) {
      final first = parts.first.replaceFirst(RegExp(r'^ال'), '');
      return String.fromCharCode(
        (first.isEmpty ? parts.first : first).runes.first,
      );
    }
    final a = String.fromCharCode(parts.first.runes.first);
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(a)) return '#';
    final b = parts.length > 1
        ? String.fromCharCode(parts.last.runes.first)
        : '';
    return (a + (RegExp(r'\p{L}', unicode: true).hasMatch(b) ? b : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = person.displayName;
    final bg = p.avatars[(name.hashCode & 0x7fffffff) % p.avatars.length];
    final ini = initials(person.hasName ? name : '');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? p.accent : bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (c, a) => ScaleTransition(
          scale: a,
          child: FadeTransition(opacity: a, child: c),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('c'),
                color: p.onAccent,
                size: size * 0.5,
              )
            : Text(
                ini,
                key: ValueKey(ini),
                style: TextStyle(
                  fontFamily: Type.serif,
                  fontFamilyFallback: Type.fallback,
                  fontSize: size * (ini.length > 1 ? 0.38 : 0.44),
                  color: p.ink.withValues(alpha: 0.78),
                  height: 1.1,
                ),
              ),
      ),
    );
  }
}

class HighlightText extends StatelessWidget {
  final String text;
  final List<(int, int)> ranges;
  final TextStyle style;
  const HighlightText(
    this.text, {
    super.key,
    required this.ranges,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final p = context.pal;
    final spans = <TextSpan>[];
    var i = 0;
    for (final (a0, b0) in ranges) {
      final a = a0.clamp(0, text.length), b = b0.clamp(0, text.length);
      if (a < i || a >= b) continue;
      if (a > i) spans.add(TextSpan(text: text.substring(i, a)));
      spans.add(
        TextSpan(
          text: text.substring(a, b),
          style: TextStyle(
            color: p.accent,
            decoration: TextDecoration.underline,
            decorationColor: p.accent.withValues(alpha: 0.35),
            decorationThickness: 2,
          ),
        ),
      );
      i = b;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return Text.rich(
      TextSpan(children: spans, style: style),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const Tag(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = color ?? p.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: c.withValues(alpha: 0.1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final bool expand;
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final child = Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.paper),
            )
          else if (icon != null)
            Icon(icon, color: p.paper, size: 20),
          if (busy || icon != null) const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.paper,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
    return Pressable(onTap: busy ? null : onTap, haptic: true, child: child);
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const GhostButton({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.hairline, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: p.ink),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  const Pill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? p.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? p.ink : p.hairline, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: active ? p.paper : p.inkSoft),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? p.paper : p.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormatGlyph extends StatelessWidget {
  final Format format;
  final double size;
  final bool active;
  const FormatGlyph(
    this.format, {
    super.key,
    this.size = 44,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: size,
      height: size * 1.18,
      decoration: BoxDecoration(
        color: active ? p.accent : p.sheet,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.16),
          bottomLeft: Radius.circular(size * 0.16),
          bottomRight: Radius.circular(size * 0.16),
          topRight: Radius.circular(size * 0.34),
        ),
        border: Border.all(color: active ? p.accent : p.hairline, width: 1.2),
      ),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: size * 0.16),
      child: Text(
        '.${format.ext}',
        style: TextStyle(
          fontSize: size * (format.ext.length > 4 ? 0.2 : 0.24),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: active ? p.onAccent : p.ink,
        ),
      ),
    );
  }
}

String formatBlurb(L l, Format f) => switch (f) {
  Format.csv => l.t('formatCsv'),
  Format.vcf => l.t('formatVcf'),
  Format.xlsx => l.t('formatXlsx'),
  Format.txt => l.t('formatTxt'),
  Format.json => l.t('formatJson'),
  Format.numbers => l.t('formatNumbers'),
};

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: Type.label(p))),
          ?trailing,
        ],
      ),
    );
  }
}

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 45),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay * math.min(widget.index, 12), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - a.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

void toast(
  BuildContext context,
  String msg, {
  String? action,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 2600),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      action: action == null
          ? null
          : SnackBarAction(label: action, onPressed: onAction ?? () {}),
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: context.pal.hairline,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
