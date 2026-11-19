// Golden coverage for the extracted home-list session row (THE-46).
//
// Mirrors the harness in components_golden_test.dart: real UI fonts, the
// aurora token scope, a fixed 390x844 surface, and animations disabled so the
// raster is deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/core/protocol/responses.dart' show RpcSessionInfo;
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/sessions/widgets/session_row.dart';

import '../support/load_fonts.dart';

const _size = Size(390, 844);

Future<void> _pump(WidgetTester tester, bool dark, Widget child) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final base = dark ? PiTheme.dark : PiTheme.light;
  // PiTheme pins ListTile title/subtitle styles without a font family, so the
  // themed textTheme alone does not reach them. Pin both to Roboto here so
  // the golden verifies real glyphs on every runner (production keeps the
  // platform default).
  final listTileTheme = base.listTileTheme.copyWith(
    titleTextStyle:
        base.listTileTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    subtitleTextStyle:
        base.listTileTheme.subtitleTextStyle?.copyWith(fontFamily: 'Roboto'),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          listTileTheme: listTileTheme,
        ),
        builder: (context, child) => PiColorsScope(
          skin: 'aurora',
          child: child ?? const SizedBox.shrink(),
        ),
        home: MediaQuery(
          data: const MediaQueryData(size: _size, disableAnimations: true),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
  // ListTile wraps its title/subtitle in AnimatedDefaultTextStyle; pump past
  // kThemeChangeDuration so the golden captures the themed (Roboto) style
  // rather than the test binding's fallback font mid-animation.
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 300));
}

/// A populated row: name, project path, relative age, message count, and the
/// `child` badge from `parentSessionPath`.
RpcSessionInfo _populatedSession() {
  // Pinned to a fixed offset from "now" so _relativeTime renders a stable
  // "2h ago" on every run.
  final modified = DateTime.now().subtract(const Duration(hours: 2));
  return RpcSessionInfo(
    path: '/Users/dev/.acoder/sessions/b7f2a1c9.jsonl',
    id: 'b7f2a1c9',
    cwd: '/Users/dev/projects/acoder-mobile',
    name: 'Wire up the session list',
    parentSessionPath: '/Users/dev/.acoder/sessions/0a91fe.jsonl',
    created: modified.toIso8601String(),
    modified: modified.toIso8601String(),
    messageCount: 12,
  );
}

Widget _row(RpcSessionInfo session, {VoidCallback? onTap}) => SessionRow(
      session: session,
      connected: true,
      pinned: false,
      onTap: onTap ?? () {},
      onRename: () {},
      onDelete: () {},
      onStop: () {},
      onTogglePin: () {},
      onBranches: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  setUpAll(loadUiFonts);

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('session_row_populated_390x844_$mode', (tester) async {
      final session = _populatedSession();
      await _pump(tester, dark, _row(session));

      // Explicit assertions so a broken row fails as a test failure, not just
      // as a pixel diff: title, preview (project path), time, and child badge.
      expect(find.text('Wire up the session list'), findsOneWidget);
      expect(find.text('/Users/dev/projects/acoder-mobile'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      expect(find.text('12 messages'), findsOneWidget);
      expect(find.text('child'), findsOneWidget);

      await expectLater(
        find.byType(SessionRow),
        matchesGoldenFile('session_row_populated_390x844_$mode.png'),
      );
    });
  }

  testWidgets('session row falls back to first message when unnamed',
      (tester) async {
    final session = RpcSessionInfo(
      path: '/Users/dev/.acoder/sessions/c4d5e6.jsonl',
      id: 'c4d5e6',
      cwd: '/Users/dev/projects/acoder-mobile',
      firstMessage: 'Refactor the bridge handshake',
      created: DateTime.now().toIso8601String(),
      modified: DateTime.now().toIso8601String(),
      messageCount: 3,
    );
    await _pump(tester, true, _row(session));

    expect(find.text('Refactor the bridge handshake'), findsOneWidget);
    expect(find.text('child'), findsNothing);
  });

  testWidgets('session row tap invokes the callback', (tester) async {
    var taps = 0;
    await _pump(tester, true, _row(_populatedSession(), onTap: () => taps++));

    await tester.tap(find.byType(SessionRow));
    await tester.pump();

    expect(taps, 1);
  });
}
