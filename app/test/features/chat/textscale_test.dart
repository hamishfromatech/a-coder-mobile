import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/features/chat/screens/chat_screen.dart';
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

void main() {
  testWidgets('chat widgets at textScaler 2.0 do not overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0), size: Size(390, 844)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  UserMessageBubble(text: 'A very long user message that should wrap without overflowing the viewport at double text scale.'),
                  ThinkingBlock(thinking: 'A detailed thinking trace that wraps around under enlarged text settings.'),
                  UiRequestCard(
                    request: er.UiRequest(
                      id: 'u1',
                      method: 'confirm',
                      kind: 'permission',
                      toolName: 'bash',
                      message: 'npm test',
                      title: 'Permission',
                    ),
                  ),
                  JumpToLatestPill(unreadCount: 12, onTap: _noop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
