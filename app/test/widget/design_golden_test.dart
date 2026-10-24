import 'package:acoder_mobile/design/components/status_dot.dart';
import 'package:acoder_mobile/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [true, false]) {
    for (final width in [320.0, 360.0, 411.0]) {
      testWidgets('status dot golden ${dark ? 'dark' : 'light'} $width', (tester) async {
        tester.view.physicalSize = Size(width, 120);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? PiTheme.dark : PiTheme.light,
            home: const Scaffold(
              body: Center(child: StatusDot(type: StatusDotType.live, size: 8)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/statusdot_${dark ? 'dark' : 'light'}_${width.toInt()}.png'),
        );
      });
    }
  }
}
