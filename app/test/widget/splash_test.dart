// Splash tests: DecodeText scramble/resolve behavior + ConnectingOverlay
// cold-boot gating (visible while connecting, exits on ready, never
// resurrects after a healthy boot).
library;

import 'package:acoder_mobile/core/connection/connection_state.dart' as conn;
import 'package:acoder_mobile/design/components/decode_text.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:acoder_mobile/features/splash/connecting_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DecodeText', () {
    testWidgets('renders the resolved text once fully decoded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
                child:
                    DecodeText(text: 'CONNECTING', cursor: true, loop: false)),
          ),
        ),
      );
      // After enough ticks for a full resolve + hold, the plain text shows.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('CONNECTING'), findsOneWidget);
    });

    testWidgets('prefix characters never scramble', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
              body: Center(
                  child: DecodeText(text: 'AB-CD', prefix: 3, active: true))),
        ),
      );
      // Any render must start with the untouched prefix.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 45));
        final text = tester.widget<Text>(find.byType(Text).first);
        final span = text.textSpan! as TextSpan;
        expect((span.text ?? '').startsWith('AB-'), isTrue);
      }
    });
  });

  group('ConnectingOverlay', () {
    // Test-controlled connection state; the overlay's projection provider is
    // overridden to read from it so tests can drive state changes in one scope.
    final testStateProvider = StateProvider<SessionControllerState>(
      (ref) => const SessionControllerState(
        connection: conn.ConnectionInfo(state: conn.ConnectionState.connecting),
      ),
    );

    Widget host() {
      return ProviderScope(
        overrides: [
          connectionStateProvider('h1')
              .overrideWith((ref) => ref.watch(testStateProvider))
        ],
        child: const MaterialApp(
          home: Stack(children: [SizedBox(), ConnectingOverlay(hostId: 'h1')]),
        ),
      );
    }

    Future<void> emit(WidgetTester tester, SessionControllerState state) async {
      final container = ProviderScope.containerOf(
          tester.element(find.byType(ConnectingOverlay)));
      container.read(testStateProvider.notifier).state = state;
      await tester.pump();
    }

    testWidgets('shows the scramble while connecting, exits once ready',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 50));
      // The overlay is up with the scramble running.
      expect(find.byType(DecodeText), findsOneWidget);

      // Ready → exit choreography: text-out (360) + hold (300) + overlay-out (520).
      await emit(
          tester,
          const SessionControllerState(
              connection:
                  conn.ConnectionInfo(state: conn.ConnectionState.ready)));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(DecodeText), findsNothing);
    });

    testWidgets('exits on ready even if `starting` was never cleared',
        (tester) async {
      // Regression: the controller used to keep `starting: true`, so isReady
      // stayed false and the splash never left the screen although the app
      // was fully connected.
      expect(
        const SessionControllerState(
          connection: conn.ConnectionInfo(state: conn.ConnectionState.ready),
          starting: true,
        ).isReady,
        isTrue,
      );

      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 50));
      await emit(
        tester,
        const SessionControllerState(
          connection: conn.ConnectionInfo(state: conn.ConnectionState.ready),
          starting: true,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(DecodeText), findsNothing);
    });

    testWidgets(
        'does not resurrect after a healthy boot (reconnecting is banner territory)',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 50));
      await emit(
          tester,
          const SessionControllerState(
              connection:
                  conn.ConnectionInfo(state: conn.ConnectionState.ready)));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(DecodeText), findsNothing);

      // Drop + reconnect later — overlay must stay gone.
      await emit(
          tester,
          const SessionControllerState(
            connection: conn.ConnectionInfo(
                state: conn.ConnectionState.reconnecting, reconnectAttempt: 2),
          ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DecodeText), findsNothing);
    });

    testWidgets('steps aside on a fatal error before first connect',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 50));
      await emit(
          tester,
          const SessionControllerState(
            connection: conn.ConnectionInfo(
              state: conn.ConnectionState.disconnected,
              errorMessage: '401 — wrong token',
            ),
          ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DecodeText), findsNothing);
    });
  });
}
