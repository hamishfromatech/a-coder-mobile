import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/design/components/status_dot.dart';
import 'package:acoder_mobile/design/components/chip.dart';
import 'package:acoder_mobile/design/components/banner.dart';
import 'package:acoder_mobile/design/components/empty_state.dart';
import 'package:acoder_mobile/features/tools/tool_card.dart';

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
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? PiTheme.dark : PiTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

String _suffix(Size size, bool dark) =>
    '${size.width.toInt()}x${size.height.toInt()}_${dark ? "dark" : "light"}';

void main() {
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
  }
}