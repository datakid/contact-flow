import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models/person.dart';
import '../domain/reach.dart';
import 'reach_ui.dart';
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
    if (!enabled || person.phones.isEmpty) return child;
    final p = context.pal;
    final l = L.of(context);
    final number = person.phones.first.number;
    Widget side(AlignmentGeometry align, IconData icon, String label) {
      return Container(
        color: p.accentSoft,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Semantics(
          label: label,
          child: Icon(icon, color: p.accentText, size: 26),
        ),
      );
    }

    return Dismissible(
      key: ValueKey('swipe-${person.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: side(
        AlignmentDirectional.centerStart,
        Icons.call_rounded,
        l.t('swipeCall'),
      ),
      secondaryBackground: side(
        AlignmentDirectional.centerEnd,
        Icons.sms_rounded,
        l.t('swipeMessage'),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        await reachOut(
          context,
          direction == DismissDirection.startToEnd ? Channel.call : Channel.sms,
          number,
        );
        return false;
      },
      child: child,
    );
  }
}
