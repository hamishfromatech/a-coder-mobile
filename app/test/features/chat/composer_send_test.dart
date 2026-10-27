// Regression: Send enables as soon as the composer has text (previously the
// button only refreshed on an unrelated setState, e.g. toggling Send/Queue).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/chat/screens/chat_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  bool sendEnabled(WidgetTester tester) {
    final finder = find.ancestor(
      of: find.byIcon(Icons.keyboard_return_rounded),
      matching: find.byType(GestureDetector),
    );
    if (finder.evaluate().isEmpty) return false;
    return tester.widget<GestureDetector>(finder.first).onTap != null;
  }

  testWidgets('typing enables Send without any other interaction',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PiTheme.dark,
          builder: (context, child) => PiColorsScope(
            skin: 'aurora',
            child: child ?? const SizedBox.shrink(),
          ),
          home: const ChatScreen(hostId: 'test-host'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(sendEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.pump();

    expect(sendEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(sendEnabled(tester), isFalse);
  });
}
