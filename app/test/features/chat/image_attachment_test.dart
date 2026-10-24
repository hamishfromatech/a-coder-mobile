// Inline image attachments in transcript history.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/features/chat/screens/chat_screen.dart';

/// 1x1 transparent PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  testWidgets('user bubble renders an inline image and opens the viewer',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserMessageBubble(
            text: 'Look at this',
            images: [
              {'type': 'image', 'data': _pngBase64, 'mimeType': 'image/png'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Look at this'), findsOneWidget);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('corrupt image data fails soft without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserMessageBubble(
            text: 'broken',
            images: [
              {'type': 'image', 'data': 'not-base64!!', 'mimeType': 'image/png'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('text-only bubbles have no image widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserMessageBubble(text: 'no image')),
      ),
    );
    expect(find.byType(Image), findsNothing);
  });
}
