import 'package:contact_flow/ui/theme.dart';
import 'package:contact_flow/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: w!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('the skeleton shows its rows and caption', (t) async {
    await t.pumpWidget(host(const ListSkeleton(rows: 4, caption: 'Loading')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('list-skeleton')), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('it pulses unless motion is reduced', (t) async {
    await t.pumpWidget(host(const ListSkeleton()));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(host(const ListSkeleton(), reduceMotion: true));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(t.hasRunningAnimations, isFalse);
  });
}
