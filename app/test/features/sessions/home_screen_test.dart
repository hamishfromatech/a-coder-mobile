// Home screen empty-state coverage (THE-46).
//
// The populated-row rendering is covered by the golden tests in
// test/golden/session_row_golden_test.dart; this exercises the list's
// empty state end to end (connected host, zero sessions) without a live
// socket. The generic EmptyState component already has a golden in
// test/golden/components_golden_test.dart; these assertions guard the copy
// and branch HomeScreen actually chooses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/core/connection/connection_state.dart' as cs;
import 'package:acoder_mobile/core/connection/host_registry.dart';
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:acoder_mobile/features/sessions/screens/home_screen.dart';

const _hostId = 'host-the-46';

/// Disconnected from the wire: keeps the provider's real constructor but
/// skips `start()`, so the screen sees a ready, empty session list.
class _FakeSessionController extends SessionController {
  _FakeSessionController(super.ref, super.hostId) {
    state = const SessionControllerState(
      connection: cs.ConnectionInfo(state: cs.ConnectionState.ready),
    );
  }

  @override
  Future<void> refreshSessions() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('empty session list shows the "No sessions yet" state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final host = PairedHost(
      id: _hostId,
      name: 'Dev MacBook',
      host: '127.0.0.1',
      port: 4317,
      tls: false,
      lastConnected: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeHostProvider.overrideWith((ref) async => host),
          sessionControllerProvider.overrideWith(
            (ref, hostId) => _FakeSessionController(ref, hostId),
          ),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          builder: (context, child) => PiColorsScope(
            skin: 'aurora',
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HomeScreen(activeHostId: _hostId),
        ),
      ),
    );

    // initState schedules the first sync in a microtask; let it settle before
    // asserting so the loading shimmer has been replaced by the empty state.
    await tester.pump();
    await tester.pump();

    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.text('Start one from the + button.'), findsOneWidget);
  });
}
