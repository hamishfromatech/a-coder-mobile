// Bridge control-frame handling (doc 04 §6).
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/connection/connection_manager.dart';
import 'package:acoder_mobile/core/connection/connection_state.dart';
import 'package:acoder_mobile/core/connection/rpc_client.dart';
import 'package:acoder_mobile/core/protocol/events.dart';

ConnectionManager _manager() {
  final manager = ConnectionManager(
    client: RpcClient(wsUrl: 'ws://127.0.0.1:9/rpc', token: 'test-token'),
    hostUrl: 'ws://127.0.0.1:9/rpc',
  );
  manager.onEvent = (_, __) {};
  manager.onBridgeFrame = (_) {};
  manager.onError = (_) {};
  addTearDown(manager.dispose);
  return manager;
}

void main() {
  test('engine_unavailable surfaces a clear message, not "unknown frame"', () {
    final manager = _manager();
    final logged = <String>[];
    manager.onError = logged.add;

    manager.handleBridgeFrame(
      const BridgeControlFrame(event: 'engine_unavailable'),
    );

    expect(manager.currentState.errorMessage, engineStartingMessage);
    expect(logged.single, engineStartingMessage);
    // The socket is still usable — only the engine is starting.
    expect(manager.currentState.state, isNot(ConnectionState.shuttingDown));
    expect(manager.currentState.isDisconnected, isTrue); // never connected yet
  });

  test('engine_unavailable with backlog says the command was dropped', () {
    final manager = _manager();
    final logged = <String>[];
    manager.onError = logged.add;

    manager.handleBridgeFrame(
      const BridgeControlFrame(event: 'engine_unavailable', reason: 'backlog'),
    );

    expect(manager.currentState.errorMessage, engineBusyMessage);
    expect(logged.single, engineBusyMessage);
    expect(manager.currentState.state, isNot(ConnectionState.shuttingDown));
  });

  test('engine_unavailable reason survives the frame round trip', () {
    final frame = BridgeControlFrame.fromJson(
      const {
        'type': 'bridge',
        'event': 'engine_unavailable',
        'reason': 'backlog'
      },
    );
    expect(frame.reason, 'backlog');
    expect(frame.toJson()['reason'], 'backlog');
  });

  test('engine_failed is terminal and explains restart attempts', () {
    final manager = _manager();
    manager.handleBridgeFrame(
      const BridgeControlFrame(event: 'engine_failed', attempts: 2),
    );
    expect(manager.currentState.state, ConnectionState.disconnected);
    expect(manager.currentState.errorMessage, contains('2'));
  });

  test('shutting_down moves to shuttingDown and disconnects', () {
    final manager = _manager();
    manager.handleBridgeFrame(
      const BridgeControlFrame(event: 'shutting_down'),
    );
    expect(manager.currentState.state, ConnectionState.shuttingDown);
  });
}
