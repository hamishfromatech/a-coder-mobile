import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:acoder_mobile/core/connection/rpc_client.dart';
import 'package:acoder_mobile/core/connection/connection_state.dart';
import 'package:acoder_mobile/core/protocol/events.dart';

import '../test/support/fake_bridge_server.dart';

class _Listener implements RpcClientListener {
  _Listener(this.onEvt, this.onErr);
  final void Function(String, Map<String, dynamic>) onEvt;
  final void Function(String) onErr;

  @override
  void onEvent(String eventType, Map<String, dynamic> data) => onEvt(eventType, data);
  @override
  void onBridgeFrame(BridgeControlFrame frame) {}
  @override
  void onConnectionStateChange(ConnectionInfo info) {}
  @override
  void onError(String message) => onErr(message);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('happy path: prompt -> tool approval -> steer -> final answer', (tester) async {
    const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final server = FakeBridgeServer(token: token);
    await server.start();
    addTearDown(() async => await server.stop());

    final client = RpcClient(wsUrl: 'ws://127.0.0.1:${server.port}/rpc', token: token);
    final eventTypes = <String>[];
    final done = Completer<void>();
    client.listener = _Listener(
      (type, data) {
        eventTypes.add(type);
        if (type == 'extension_ui_request') {
          final id = data['id'] as String?;
          unawaited(() async {
            await client.sendCommand('steer', {'message': 'also add tests'});
            if (id != null) {
              client.sendRaw(jsonEncode(<String, dynamic>{
                'type': 'extension_ui_response',
                'id': id,
                'confirmed': true,
              }));
            }
          }());
        } else if (type == 'agent_end') {
          if (!done.isCompleted) done.complete();
        }
      },
      (m) => fail(m),
    );

    await client.connect();
    unawaited(client.sendCommand('prompt', {'message': 'rename foo to bar'}));
    await done.future.timeout(const Duration(seconds: 15));

    expect(eventTypes, contains('agent_start'));
    expect(eventTypes, contains('extension_ui_request'));
    expect(eventTypes, contains('tool_execution_end'));
    expect(eventTypes, contains('agent_end'));

    await client.disconnect();
  });
}