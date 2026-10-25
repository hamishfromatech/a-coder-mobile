// Component-kit parity: the desktop vocabulary renders in the mobile kit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/design/components/button.dart';
import 'package:acoder_mobile/design/components/kit.dart';
import 'package:acoder_mobile/design/components/kit2.dart';
import 'package:acoder_mobile/design/theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: PiTheme.dark,
      builder: (context, c) => PiColorsScope(
        skin: 'aurora',
        child: c ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('button variants render their labels', (tester) async {
    await tester.pumpWidget(_host(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in PiButtonVariant.values)
            PiButton(label: v.name, variant: v, onPressed: () {}),
        ],
      ),
    ));
    for (final v in PiButtonVariant.values) {
      expect(find.text(v.name), findsOneWidget);
    }
  });

  testWidgets('icon button exposes a semantic label', (tester) async {
    await tester.pumpWidget(_host(
      PiIconButton(
        icon: Icons.settings,
        semanticLabel: 'Settings',
        onPressed: () {},
      ),
    ));
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
  });

  testWidgets('switch toggles through the callback', (tester) async {
    var value = false;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => PiSwitch(
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    expect(value, isFalse);
    await tester.tap(find.byType(PiSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('segmented control reports the selected value', (tester) async {
    var selected = 'low';
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => PiSegmentedControl<String>(
        value: selected,
        label: 'thinking',
        options: const [
          PiSegment('off', 'off'),
          PiSegment('low', 'low'),
          PiSegment('high', 'high'),
        ],
        onChanged: (v) => setState(() => selected = v),
      ),
    )));
    expect(find.text('THINKING'), findsOneWidget);
    await tester.tap(find.text('HIGH'));
    await tester.pumpAndSettle();
    expect(selected, 'high');
  });

  testWidgets('badge renders uppercase label', (tester) async {
    await tester.pumpWidget(_host(
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PiBadge(label: 'running', variant: PiBadgeVariant.accent),
          PiBadge(label: 'error', variant: PiBadgeVariant.error),
        ],
      ),
    ));
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('search field clears through its callback', (tester) async {
    var query = 'abc';
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => PiSearchField(
        value: query,
        semanticLabel: 'Search',
        onChange: (q) => setState(() => query = q),
      ),
    )));
    expect(find.text('abc'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pumpAndSettle();
    expect(query, isEmpty);
  });

  testWidgets('error state shows the canonical glyph and title', (tester) async {
    await tester.pumpWidget(_host(
      const PiErrorState(
        title: 'Bridge unreachable',
        description: 'Check that the host is running.',
      ),
    ));
    expect(find.byType(PiErrorIcon), findsOneWidget);
    expect(find.text('Bridge unreachable'), findsOneWidget);
    expect(find.text('Check that the host is running.'), findsOneWidget);
  });
}
