// Shell parity: four desktop sections are always one tap away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/shell/screens/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PiTheme.dark,
          builder: (context, child) => PiColorsScope(
            skin: 'aurora',
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppShell(activeHostId: 'test-host'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shell shows the section bar', (tester) async {
    await pumpShell(tester);
    expect(find.text('SESSIONS'), findsOneWidget);
    expect(find.text('TASKS'), findsOneWidget);
    expect(find.text('OFFICE'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('tapping a section switches the visible page', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('SETTINGS'));
    await tester.pump(const Duration(milliseconds: 300));
    // Settings is the only page with the Machines/Appearance/About tabs.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
