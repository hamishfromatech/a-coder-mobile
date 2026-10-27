import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'fake_bridge_server.dart';

void main() {
  test('fake bridge health/info/ws', () async {
    final server = FakeBridgeServer(token: 'tok');
    await server.start();
    try {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/health'));
      final res = await req.close();
      expect(res.statusCode, 200);
      // WS upgrade
      final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}/rpc',
          headers: {'Authorization': 'Bearer tok'});
      ws.add('{"type":"get_state","id":"c1"}');
      final frame = await ws.first.timeout(const Duration(seconds: 2));
      expect(frame, contains('"success":true'));
      await ws.close();
    } finally {
      await server.stop();
    }
  });
}
