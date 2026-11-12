import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class SwipeAction {
  final IconData icon;
  final String label;
  final Color fill;
  final Color iconColor;
  final Color armedFill;
  final Color armedIconColor;
  final VoidCallback onCommit;
  const SwipeAction({
    required this.icon,
    required this.label,
    required this.fill,
    required this.iconColor,
    required this.armedFill,
    required this.armedIconColor,
    required this.onCommit,
  });
}

class SwipeRecognizer extends HorizontalDragGestureRecognizer {
  SwipeRecognizer({super.debugOwner});

  bool Function(Offset position)? accepts;
  Offset _origin = Offset.zero;
  Offset _moved = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final ok = accepts;
    if (ok != null && !ok(event.position)) return;
    _origin = event.position;
    _moved = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _moved = event.position - _origin;
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final slop = (deviceTouchSlop ?? kTouchSlop) * 1.6;
    final dx = _moved.dx.abs();
    final dy = _moved.dy.abs();
    return dx > slop && dx > dy * 2;
  }
}

class SwipeRow extends StatefulWidget {
  final Widget child;
  final SwipeAction? start;
  final SwipeAction? end;
  final bool enabled;
  const SwipeRow({
    super.key,
    required this.child,
    this.start,
    this.end,
    this.enabled = true,
  });

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow>
    with SingleTickerProviderStateMixin {
  static const _edgeGuard = 24.0;
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.82,
  );

  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
  );
  double _raw = 0;
  double _width = 0;
  bool _armed = false;
  bool _dragging = false;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _threshold => math.min(140.0, math.max(100.0, _width * 0.34));

  SwipeAction? _actionFor(double dx) {
    if (dx == 0) return null;
    final isStart = _rtl ? dx < 0 : dx > 0;
    return isStart ? widget.start : widget.end;
  }

  bool _accepts(Offset position) {
    if (!widget.enabled) return false;
    final screen = MediaQuery.sizeOf(context).width;
    final insets = MediaQuery.of(context).systemGestureInsets;
    final left = math.max(_edgeGuard, insets.left);
    final right = math.max(_edgeGuard, insets.right);
    return position.dx > left && position.dx < screen - right;
  }

  double _visual(double raw) {
    final t = _threshold;
    final a = raw.abs();
    final eased = a <= t ? a : t + (a - t) * 0.28;
    final capped = math.min(eased, t * 1.7);
    return raw < 0 ? -capped : capped;
  }

  void _start(DragStartDetails d) {
    _c.stop();
    final box = context.findRenderObject();
    _width = box is RenderBox && box.hasSize ? box.size.width : 360;
    _dragging = true;
    _raw = _c.value;
    _armed = false;
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    _raw += d.primaryDelta ?? d.delta.dx;
    if (_actionFor(_raw) == null) {
      _raw = 0;
      _c.value = 0;
      if (_armed) setState(() => _armed = false);
      return;
    }
    final armed = _raw.abs() >= _threshold;
    if (armed != _armed) {
      HapticFeedback.selectionClick();
      setState(() => _armed = armed);
    }
    _c.value = _visual(_raw);
  }

  void _end(DragEndDetails d) {
    if (!_dragging) return;
    final v = d.primaryVelocity ?? 0;
    final action = _actionFor(_raw);
    final backwards = _raw != 0 && v * _raw < 0 && v.abs() > 500;
    final commit = _armed && !backwards && action != null;
    _finish(v);
    if (commit) {
      HapticFeedback.mediumImpact();
      action.onCommit();
    }
  }

  void _cancel() {
    if (!_dragging) return;
    _finish(0);
  }

  void _finish(double velocity) {
    _dragging = false;
    _raw = 0;
    if (_armed) setState(() => _armed = false);
    final v = math.max(-2500.0, math.min(2500.0, velocity));
    _c.animateWith(SpringSimulation(_spring, _c.value, 0, v)).whenComplete(() {
      if (mounted && !_dragging) _c.value = 0;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _reveal(double dx) {
    final action = _actionFor(dx);
    if (action == null) return const SizedBox.shrink();
    final t = _threshold;
    final progress = math.min(1.0, dx.abs() / t);
    final physicalLeft = dx > 0;
    final armed = _armed;
    return ColoredBox(
      color: action.fill,
      child: Align(
        alignment: physicalLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: SizedBox(
          width: dx.abs(),
          child: Center(
            child: Opacity(
              opacity: math.min(1.0, progress * 1.8),
              child: Transform.scale(
                scale: 0.55 + 0.45 * progress,
                child: AnimatedScale(
                  scale: armed ? 1.1 : 1,
                  duration: AppMotion.fast,
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: armed ? action.armedFill : Colors.transparent,
                    ),
                    child: Icon(
                      action.icon,
                      size: 26,
                      color: armed ? action.armedIconColor : action.iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    final actions = <CustomSemanticsAction, VoidCallback>{
      if (widget.enabled && widget.start != null)
        CustomSemanticsAction(label: widget.start!.label):
            widget.start!.onCommit,
      if (widget.enabled && widget.end != null)
        CustomSemanticsAction(label: widget.end!.label): widget.end!.onCommit,
    };
    final body = Semantics(
      customSemanticsActions: actions,
      child: AnimatedBuilder(
        animation: _c,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final dx = _c.value.abs() < 0.5 ? 0.0 : _c.value;
          return Stack(
            children: [
              Positioned.fill(
                child: dx == 0 ? const SizedBox.shrink() : _reveal(dx),
              ),
              Transform.translate(
                offset: Offset(dx, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dx == 0 ? null : p.paper),
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        SwipeRecognizer: GestureRecognizerFactoryWithHandlers<SwipeRecognizer>(
          () => SwipeRecognizer(debugOwner: this),
          (r) {
            r
              ..dragStartBehavior = DragStartBehavior.down
              ..accepts = _accepts
              ..gestureSettings = settings
              ..onStart = _start
              ..onUpdate = _update
              ..onEnd = _end
              ..onCancel = _cancel;
          },
        ),
      },
      child: body,
    );
  }
}
