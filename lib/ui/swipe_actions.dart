import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../domain/reach.dart';
import 'reach_ui.dart';
import 'swipe_row.dart';
import 'theme.dart';

class SwipeActions extends StatelessWidget {
  final Person person;
  final bool enabled;
  final Widget child;
  const SwipeActions({
    super.key,
    required this.person,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final l = L.of(context);
    final number = person.phones.isEmpty ? '' : person.phones.first.number;
    return SwipeRow(
      enabled: enabled && person.phones.isNotEmpty,
      start: SwipeAction(
        icon: Icons.call_rounded,
        label: l.t('swipeCall'),
        fill: p.accentSoft,
        iconColor: p.accentText,
        armedFill: p.accent,
        armedIconColor: p.onAccent,
        onCommit: () => reachOut(context, Channel.call, number),
      ),
      end: SwipeAction(
        icon: Icons.sms_rounded,
        label: l.t('swipeMessage'),
        fill: p.accentSoft,
        iconColor: p.accentText,
        armedFill: p.accent,
        armedIconColor: p.onAccent,
        onCommit: () => reachOut(context, Channel.sms, number),
      ),
      child: child,
    );
  }
}
