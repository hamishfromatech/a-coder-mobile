import 'package:acoder_mobile/features/pairing/screens/pairing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR payload parsing', () {
    test('accepts valid payload', () {
      const raw = '{"v":1,"kind":"acoder","host":"192.168.1.2","port":8787,"token":"abcdefghijklmnopqrstuvwxyz0123456789ABCDEF","name":"Mac"}';
      final p = QrPairingPayload.parse(raw);
      expect(p, isNotNull);
      expect(p!.host, '192.168.1.2');
      expect(p.port, 8787);
      expect(p.token.length, greaterThanOrEqualTo(32));
    });

    test('rejects garbage', () {
      expect(QrPairingPayload.parse('hello'), isNull);
      expect(QrPairingPayload.parse('{"v":2,"kind":"acoder","host":"h","port":8787,"token":"x"}'), isNull);
    });
  });

  group('Manual validation', () {
    test('requires host + token', () {
      expect(
        validateManualPairingEntry(host: '', portText: '8787', token: 'x' * 44),
        isNotNull,
      );
      expect(
        validateManualPairingEntry(host: 'h', portText: '8787', token: 'short'),
        isNotNull,
      );
    });

    test('accepts valid entry', () {
      expect(
        validateManualPairingEntry(host: 'h', portText: '8787', token: 'a' * 44),
        isNull,
      );
    });
  });
}

