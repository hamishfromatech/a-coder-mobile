// The WS upgrade must present device identity, or the bridge records nothing
// and the desktop Mobile access card stays empty (bridge spec §5.4).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:acoder_mobile/core/connection/device_identity.dart';
import 'package:acoder_mobile/core/connection/rpc_client.dart';

class _FakeChannel with StreamChannelMixin<dynamic> implements WebSocketChannel {
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

  Future<void> close() => controller.close();
}

class _FakeSink implements WebSocketSink {
  final List<String> lines;
  _FakeSink(this.lines);
  @override
  void add(dynamic data) => lines.add(data as String);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.drain<void>();
  @override
  Future<void> close([int? closeCode, String? closeReason]) => Future.value();
  @override
  Future<void> get done => Future.value();
}

Future<Map<String, dynamic>> _connectHeaders({DeviceIdentity? device}) async {
  final channel = _FakeChannel();
  var captured = <String, dynamic>{};
  final client = RpcClient(
    wsUrl: 'ws://127.0.0.1:9/rpc',
    token: 'test-token',
    device: device,
    channelFactory: (_, {headers}) {
      captured = Map<String, dynamic>.from(headers ?? const {});
      return channel;
    },
  );
  await client.connect();
  await client.disconnect();
  await channel.close();
  return captured;
}

void main() {
  test('presents x-acoder-device-* alongside the bearer token', () async {
    final headers = await _connectHeaders(
      device: const DeviceIdentity(
          id: 'mobile-abc', name: 'Nothing Phone 2a', platform: 'android'),
    );

    expect(headers['Authorization'], 'Bearer test-token');
    expect(headers['x-acoder-device-id'], 'mobile-abc');
    expect(headers['x-acoder-device-name'], 'Nothing Phone 2a');
    expect(headers['x-acoder-device-platform'], 'android');
  });

  test('identity header is the same value on every reconnect', () async {
    const device = DeviceIdentity(
        id: 'mobile-abc', name: 'Nothing Phone 2a', platform: 'android');
    final first = await _connectHeaders(device: device);
    final second = await _connectHeaders(device: device);

    expect(second['x-acoder-device-id'], first['x-acoder-device-id']);
  });

  test('without identity the upgrade carries only auth (old behaviour)',
      () async {
    final headers = await _connectHeaders();

    expect(headers['Authorization'], 'Bearer test-token');
    expect(headers.keys.where((k) => k.startsWith('x-acoder-device-')), isEmpty);
  });
}
