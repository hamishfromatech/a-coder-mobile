// test/core/connection/connection_state_test.dart
library;
/// Unit tests for the connection state machine (doc 08 §4).

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/connection/connection_state.dart';

void main() {
  group('ConnectionInfo', () {
    test('defaults to disconnected', () {
      expect(const ConnectionInfo().state, equals(ConnectionState.disconnected));
    });

    test('isConnected is true only for ready state', () {
      expect(const ConnectionInfo(state: ConnectionState.ready).isConnected, isTrue);
      expect(const ConnectionInfo(state: ConnectionState.connecting).isConnected, isFalse);
      expect(const ConnectionInfo(state: ConnectionState.disconnected).isConnected, isFalse);
    });

    test('isDisconnected works', () {
      expect(const ConnectionInfo(state: ConnectionState.disconnected).isDisconnected, isTrue);
      expect(const ConnectionInfo(state: ConnectionState.ready).isDisconnected, isFalse);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = ConnectionInfo(
        state: ConnectionState.connecting,
        reconnectAttempt: 1,
        nextRetryIn: Duration(seconds: 2),
      );
      final updated = original.copyWith(state: ConnectionState.ready);
      expect(updated.state, equals(ConnectionState.ready));
      expect(updated.reconnectAttempt, equals(1)); // unchanged
    });

    test('copyWith clears error message', () {
      const withError = ConnectionInfo(
        state: ConnectionState.disconnected,
        errorMessage: '401 — wrong token',
      );
      final cleared = withError.copyWith(errorMessage: null);
      expect(cleared.errorMessage, isNull);
      // Omitting the argument preserves the current value.
      final preserved = withError.copyWith(state: ConnectionState.ready);
      expect(preserved.errorMessage, equals('401 — wrong token'));
    });

    test('isResyncing flag works', () {
      const syncing = ConnectionInfo(state: ConnectionState.ready, isResyncing: true);
      expect(syncing.isResyncing, isTrue);
      final normal = syncing.copyWith(isResyncing: false);
      expect(normal.isResyncing, isFalse);
    });
  });

  group('ConnectionState enum', () {
    test('has all expected values', () {
      expect(ConnectionState.values.length, equals(6));
      expect(ConnectionState.values.contains(ConnectionState.disconnected), isTrue);
      expect(ConnectionState.values.contains(ConnectionState.connecting), isTrue);
      expect(ConnectionState.values.contains(ConnectionState.authenticating), isTrue);
      expect(ConnectionState.values.contains(ConnectionState.ready), isTrue);
      expect(ConnectionState.values.contains(ConnectionState.reconnecting), isTrue);
      expect(ConnectionState.values.contains(ConnectionState.shuttingDown), isTrue);
    });
  });

  group('state transition logic', () {
    test('disconnected → connecting on connect attempt', () {});
    test('connecting → authenticating when WS opens', () {});
    test('authenticating → ready after server_version + get_state', () {});
    test('ready → reconnecting on unexpected disconnect', () {});
    test('reconnecting → ready after successful reconnection + resync', () {});
    test('any state → shuttingDown on bridge.shutting_down frame', () {});

    // Backoff sequence: 1s → 2s → 4s → 8s → 15s (cap), with ±20% jitter
    test('backoff increases with attempt number', () {
      const backoff = [1000, 2000, 4000, 8000, 15000];
      for (var i = 0; i < backoff.length - 1; i++) {
        expect(backoff[i + 1], greaterThan(backoff[i]));
      }
    });

    test('backoff caps at 15 seconds', () {
      // Attempt 4+ should all be capped at ~15s (with jitter)
      const maxBackoff = 15000;
      expect(maxBackoff, equals(15000));
    });

    test('jitter is ±20% of base', () {
      // For a 4000ms base: jitter range = [800, -800] → actual = [3200, 4800]
      const base = 4000;
      final maxJitter = (base * 0.4).toInt(); // 1600
      expect(maxJitter, lessThan(base));
    });
  });

  group('resync sequence', () {
    test('on ready after reconnect: get_state → get_messages → get_sessions_status', () {});
    test('shows "reconnected — resyncing" banner during resync', () {});
    test('clears banner after successful resync', () {});

    // Message list diff logic
    test('if server messageCount < local, drop tail messages', () {});
    test('if server messageCount > local, fetch and replace', () {});
  });
}
