import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/load_fonts.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/design/components/status_dot.dart';
import 'package:acoder_mobile/design/components/chip.dart';
import 'package:acoder_mobile/design/components/banner.dart';
import 'package:acoder_mobile/design/components/empty_state.dart';
import 'package:acoder_mobile/features/tools/tool_card.dart';
import 'package:acoder_mobile/features/chat/screens/chat_screen.dart';
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

const _sizes = <Size>[
  Size(320, 640),
  Size(390, 844),
  Size(430, 932),
];

Future<void> _pump(
  WidgetTester tester,
  Size size,
  bool dark,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final base = dark ? PiTheme.dark : PiTheme.light;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
        ),
        // Mirrors ACoderApp: refresh the static token set for the theme mode.
        builder: (context, child) => PiColorsScope(
          skin: 'aurora',
          child: child ?? const SizedBox.shrink(),
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

String _suffix(Size size, bool dark) =>
    '${size.width.toInt()}x${size.height.toInt()}_${dark ? "dark" : "light"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  setUpAll(loadUiFonts);

  for (final size in _sizes) {
    for (final dark in [true, false]) {
      testWidgets('status_dot_live_${_suffix(size, dark)}', (tester) async {
        await _pump(tester, size, dark, const StatusDot(type: StatusDotType.live, size: 8));
        await expectLater(find.byType(StatusDot), matchesGoldenFile('status_dot_live_${_suffix(size, dark)}.png'));
      });

      testWidgets('status_chip_${_suffix(size, dark)}', (tester) async {
        await _pump(tester, size, dark, const StatusChip(label: 'model • opus', variant: ChipVariant.accent));
        await expectLater(find.byType(StatusChip), matchesGoldenFile('status_chip_${_suffix(size, dark)}.png'));
      });

      testWidgets('banner_reconnecting_${_suffix(size, dark)}', (tester) async {
        await _pump(
          tester,
          size,
          dark,
          const ConnectionBanner(type: BannerType.reconnecting, message: 'Reconnecting… attempt 3', attemptText: 'attempt 3'),
        );
        await expectLater(find.byType(ConnectionBanner), matchesGoldenFile('banner_reconnecting_${_suffix(size, dark)}.png'));
      });

      testWidgets('empty_state_${_suffix(size, dark)}', (tester) async {
        await _pump(
          tester,
          size,
          dark,
          const EmptyState(icon: Icons.inbox_outlined, title: 'No sessions yet', hint: 'Tap + to start a new session'),
        );
        await expectLater(find.byType(EmptyState), matchesGoldenFile('empty_state_${_suffix(size, dark)}.png'));
      });

      testWidgets('tool_card_edit_${_suffix(size, dark)}', (tester) async {
        await _pump(
          tester,
          size,
          dark,
          const SizedBox(
            width: 360,
            child: ToolCard(
              toolName: 'edit',
              args: {'path': 'src/x.ts'},
              result: {'details': {'diff': '--- a\n+++ b\n@@ -1 +1 @@\n-foo()\n+bar()'}},
            ),
          ),
        );
        await expectLater(find.byType(ToolCard), matchesGoldenFile('tool_card_edit_${_suffix(size, dark)}.png'));
      });

      testWidgets('diff_lines_${_suffix(size, dark)}', (tester) async {
        await _pump(
          tester,
          size,
          dark,
          const SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DiffRow(line: '+bar()'),
                DiffRow(line: '-foo()'),
                DiffRow(line: ' ctx'),
                DiffRow(line: '@@ -1,3 +1,3 @@'),
              ],
            ),
          ),
        );
        // Golden targets the column's render
        await expectLater(find.byType(Column), matchesGoldenFile('diff_lines_${_suffix(size, dark)}.png'));
      });
    }
    // Batch 3 — chat bubble / thinking / approval / queue / jump pill goldens (390x844)
  for (final dark in [true, false]) {
    testWidgets('user_message_bubble_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(tester, const Size(390, 844), dark, const SizedBox(width: 360, child: UserMessageBubble(text: 'Hello from user with a longish line that wraps.')));
      await expectLater(find.byType(UserMessageBubble), matchesGoldenFile('user_message_bubble_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('assistant_message_with_code_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(
        tester,
        const Size(390, 844),
        dark,
        const SizedBox(
          width: 360,
          child: AssistantMessageView(
            message: er.UiMessage(id: 'a', role: 'assistant', content: <String, dynamic>{}),
            parts: <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': 'Here is code:\n```dart\nvoid main() {\n  print("hi");\n}\n```'}
            ],
            toolCards: <String, er.ToolCardState>{},
          ),
        ),
      );
      await expectLater(find.byType(AssistantMessageView), matchesGoldenFile('assistant_message_with_code_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('thinking_block_collapsed_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(tester, const Size(390, 844), dark, const SizedBox(width: 360, child: ThinkingBlock(thinking: 'Working through the problem step by step.')));
      await expectLater(find.byType(ThinkingBlock), matchesGoldenFile('thinking_block_collapsed_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('thinking_block_expanded_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(tester, const Size(390, 844), dark, const SizedBox(width: 360, child: ThinkingBlock(thinking: 'Working through the problem step by step.')));
      await tester.tap(find.byType(ThinkingBlock));
      await tester.pump();
      await expectLater(find.byType(ThinkingBlock), matchesGoldenFile('thinking_block_expanded_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('approval_card_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(
        tester,
        const Size(390, 844),
        dark,
        const SizedBox(
          width: 360,
          child: UiRequestCard(
            request: er.UiRequest(id: 'u1', method: 'confirm', kind: 'permission', toolName: 'bash', message: 'npm test', title: 'Permission'),
          ),
        ),
      );
      await expectLater(find.byType(UiRequestCard), matchesGoldenFile('approval_card_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('queue_card_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(
        tester,
        const Size(390, 844),
        dark,
        SizedBox(
          width: 360,
          child: QueuedCard(
            queue: const er.QueueState(steering: <String>['Steer this'], followUp: <String>['Follow up later']),
            onRemove: (String kind, int index) {},
            onRestore: () {},
          ),
        ),
      );
      await expectLater(find.byType(QueuedCard), matchesGoldenFile('queue_card_390x844_${dark ? "dark" : "light"}.png'));
    });

    testWidgets('jump_to_latest_pill_390x844_${dark ? "dark" : "light"}', (tester) async {
      await _pump(tester, const Size(390, 844), dark, JumpToLatestPill(unreadCount: 3, onTap: () {}));
      await expectLater(find.byType(JumpToLatestPill), matchesGoldenFile('jump_to_latest_pill_390x844_${dark ? "dark" : "light"}.png'));
    });
  }
}
}