import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/connection/connection_state.dart' as cstate;
import 'package:acoder_mobile/core/connection/rpc_client.dart';
import 'package:acoder_mobile/core/protocol/events.dart' as proto_events;

import 'fake_bridge_server.dart';

class _Listener implements RpcClientListener {
  _Listener(this.onEvt, this.onErr);
  final void Function(String, Map<String, dynamic>) onEvt;
  final void Function(String) onErr;

  @override
  void onEvent(String eventType, Map<String, dynamic> data) =>
      onEvt(eventType, data);
  @override
  void onBridgeFrame(proto_events.BridgeControlFrame frame) {}
  @override
  void onConnectionStateChange(cstate.ConnectionInfo info) {}
  @override
  void onError(String message) => onErr(message);
}

void main() {
  test('headless protocol e2e', () async {
    const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final server = FakeBridgeServer(token: token);
    await server.start();
    addTearDown(() async => await server.stop());

    final client =
        RpcClient(wsUrl: 'ws://127.0.0.1:${server.port}/rpc', token: token);
    final eventTypes = <String>[];
    final done = Completer<void>();
    String? uiReqId;
    client.listener = _Listener(
      (type, data) {
        eventTypes.add(type);
        if (type == 'extension_ui_request') {
          uiReqId = data['id'] as String?;
          unawaited(() async {
            await client.sendCommand('steer', {'message': 'also add tests'});
            if (uiReqId != null) {
              client.sendRaw(jsonEncode(<String, dynamic>{
                'type': 'extension_ui_response',
                'id': uiReqId,
                'confirmed': true,
              }));
            }
          }());
        }
        if (type == 'agent_end') {
          if (!done.isCompleted) done.complete();
        }
      },
      (m) => fail('transport error: $m'),
    );

    await client.connect();
    await client.sendCommand('get_state', {});
    await client.sendCommand('list_sessions', {});

    unawaited(client.sendCommand('prompt', {'message': 'rename foo to bar'}));

    await done.future.timeout(const Duration(seconds: 10));

    expect(eventTypes, contains('agent_start'));
    expect(eventTypes, contains('extension_ui_request'));
    expect(eventTypes, contains('tool_execution_start'));
    expect(eventTypes, contains('agent_end'));
    expect(server.receivedCommands.any((c) => c['type'] == 'steer'), isTrue);

    await client.disconnect();
  });
}
