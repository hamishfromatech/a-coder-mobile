import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/pairing/screens/pairing_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFonts);
  for (final size in const [Size(390, 844)]) {
    for (final dark in [true, false]) {
      testWidgets('pairing_manual_${size.width.toInt()}x${size.height.toInt()}_${dark ? "dark" : "light"}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? PiTheme.dark : PiTheme.light,
            home: const PairingScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        // Switch to manual tab (camera present but not driven)
        await tester.tap(find.text('Manual'));
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(
          find.byType(PairingScreen),
          matchesGoldenFile('pairing_manual_${size.width.toInt()}x${size.height.toInt()}_${dark ? "dark" : "light"}.png'),
        );
      });
    }
  }
}