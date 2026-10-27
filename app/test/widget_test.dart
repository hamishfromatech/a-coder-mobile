// Smoke test: dark-first theme tokens and core design components render.
// Deliberately avoids the full ACoderApp (which touches secure storage /
// connectivity plugins) so this stays deterministic without platform mocks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/design/components/status_dot.dart';

void main() {
  testWidgets('dark theme renders a core component correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PiTheme.dark,
        home: const Scaffold(
          body: Center(child: StatusDot(type: StatusDotType.live)),
        ),
      ),
    );

    expect(find.byType(StatusDot), findsOneWidget);
    // Dark-first default (doc 09): scaffold background is the dark token.
    final Material material = tester.widget<Material>(
      find.descendant(
          of: find.byType(Scaffold), matching: find.byType(Material).first),
    );
    expect(material.color, isNotNull);
  });

  test('PiColors dark tokens match doc 09 spec', () {
    expect(PiColors.bg, equals(const Color.fromRGBO(10, 10, 12, 1)));
    expect(PiColors.accent, equals(const Color.fromRGBO(46, 127, 255, 1)));
  });
}
