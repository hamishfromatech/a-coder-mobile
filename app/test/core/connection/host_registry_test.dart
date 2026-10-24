library;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acoder_mobile/core/connection/host_registry.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save/get hosts atomic + corrupt JSON tolerance', () async {
    final reg = HostRegistry();
    final host = PairedHost(
      id: 'h1',
      name: 'Mac',
      host: '127.0.0.1',
      port: 8765,
      tls: false,
      lastConnected: DateTime.now(),
    );
    await reg.saveHost(host, 'secret-token');
    final hosts = await reg.getHosts();
    expect(hosts.length, 1);
    expect(hosts.first.id, 'h1');

    // corrupt JSON
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paired_hosts', '{not json');
    final hosts2 = await reg.getHosts();
    expect(hosts2, isEmpty);
  });

  test('active host fallback when missing', () async {
    final reg = HostRegistry();
    final host = PairedHost(
      id: 'h2',
      name: 'Mac2',
      host: 'localhost',
      port: 1,
      tls: false,
      lastConnected: DateTime.now(),
    );
    await reg.saveHost(host, 'tok');
    final active = await reg.getActiveHostId();
    expect(active, 'h2');
    await reg.removeHost('h2');
    expect(await reg.getActiveHostId(), isNull);
  });

  test('missing secure storage plugin does not crash', () async {
    final reg = HostRegistry();
    final host = PairedHost(
      id: 'h3',
      name: 'Mac3',
      host: 'localhost',
      port: 2,
      tls: false,
      lastConnected: DateTime.now(),
    );
    // No platform channel registered -> storage calls throw; should still save metadata.
    await reg.saveHost(host, 'tok');
    final hosts = await reg.getHosts();
    expect(hosts.length, 1);
    expect(await reg.getToken('h3'), isNull);
  });
}
