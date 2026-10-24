// Bridge control-frame handling (doc 04 §6).
import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class _FakeChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final controller = StreamController<dynamic>();
  final sent = <String>[];

  @override
  Future<void> get ready => Future.value();
  @override
  Stream<dynamic> get stream => controller.stream;
  @override
  WebSocketSink get sink => _FakeSink(sent);
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
}

class _FakeSink implements WebSocketSink {
  final List<String> lines;
  _FakeSink(this.lines);
  @override
  void add(dynamic data) {
    lines.add(data as String);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.drain<void>();
  @override
  Future<void> close([int? closeCode, String? closeReason]) => Future.value();
  @override
  Future<void> get done => Future.value();
}

RpcClient clientOf(ConnectionManager manager) => manager.client;

ConnectionManager _connectedManager(_FakeChannel channel) {
  final client = RpcClient(
    wsUrl: 'ws://127.0.0.1:9/rpc',
    token: 'test-token',
    channelFactory: (_, {headers}) => channel,
  );
  final manager =
      ConnectionManager(client: client, hostUrl: 'ws://127.0.0.1:9/rpc');
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

  test(
      'engine_unavailable fast-fails the refused command when the frame carries its id',
      () async {
    final channel = _FakeChannel();
    final manager = _connectedManager(channel);
    await clientOf(manager).connect();

    // Register a pending command through the fake channel. Attach the error
    // handler immediately: the refusal may complete the future before the
    // test reaches `await`, and an unlistened error future fails silently.
    final refuse =
        clientOf(manager).sendCommand('prompt', {'message': 'hi'}).then<Object>(
      (_) => 'unexpectedly succeeded',
      onError: (Object error) => error,
    );
    // The socket is still usable — only the engine is busy.
    final sentLine =
        channel.sent.singleWhere((line) => line.contains('prompt'));
    final sentId =
        (jsonDecode(sentLine) as Map<String, dynamic>)['id'] as String;

    // Bridge refuses it: engine not running yet.
    channel.controller.add(jsonEncode({
      'type': 'bridge',
      'event': 'engine_unavailable',
      'reason': 'starting',
      'id': sentId,
    }));

    final stopwatch = Stopwatch()..start();
    final outcome = await refuse;
    final elapsed = stopwatch.elapsed;

    // It failed from the frame, not from the 15s response timeout.
    expect(elapsed.inSeconds, lessThan(5));
    expect(outcome, isA<CommandError>());
    final error = outcome as CommandError;
    expect(error.message, engineStartingMessage);
    expect(error.id, sentId);
    expect(manager.currentState.errorMessage, engineStartingMessage);
  }, timeout: const Timeout(Duration(seconds: 30)));

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
