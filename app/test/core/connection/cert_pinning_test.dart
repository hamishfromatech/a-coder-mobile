// Certificate pinning + wss host metadata (plan M6.3).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/connection/cert_pinning.dart';
import 'package:acoder_mobile/core/connection/host_registry.dart';
import 'package:acoder_mobile/features/pairing/screens/pairing_screen.dart';

const _pin =
    '7d2bc28bb71748f97037f7856d4ff715016b69784bcd9919689d60578406a0da';

void main() {
  group('fingerprint helpers', () {
    test('normalizes colon-separated and spaced fingerprints', () {
      expect(
        normalizeFingerprint('7D:2B:C2:8B:B7:17'),
        '7d2bc28bb717',
      );
      expect(normalizeFingerprint('7D 2B C2 8B'), '7d2bc28b');
    });

    test('matches only the exact pin', () {
      expect(matchesPinnedFingerprint(_pin, _pin), isTrue);
      expect(
        matchesPinnedFingerprint(
          _pin,
          '7D:2B:C2:8B:B7:17:48:F9:70:37:F7:85:6D:4F:F7:15:'
          '01:6B:69:78:4B:CD:99:19:68:9D:60:57:84:06:A0:DA',
        ),
        isTrue,
      );
      expect(matchesPinnedFingerprint(_pin, 'deadbeef'), isFalse);
      expect(matchesPinnedFingerprint(_pin, ''), isFalse);
    });

    test('parses well-formed pins and rejects junk', () {
      expect(parseFingerprint(_pin.toUpperCase()), _pin);
      expect(parseFingerprint('not-a-fingerprint'), isNull);
      expect(parseFingerprint(null), isNull);
      expect(parseFingerprint(''), isNull);
    });

    test('derives SHA-256 of DER bytes', () {
      // SHA-256 of the empty input — a stable vector.
      expect(
        fingerprintOfDer(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('decodes PEM to DER', () {
      final der = derFromPem(
        '-----BEGIN CERTIFICATE-----\nAQID\n-----END CERTIFICATE-----\n',
      );
      expect(der, [1, 2, 3]);
      expect(derFromPem('nope'), isNull);
    });

    test('redacts pins for logs', () {
      expect(redactFingerprint(_pin), '7d2bc28b…');
      expect(redactFingerprint(''), '***');
    });
  });

  group('paired host', () {
    PairedHost host({bool tls = true, String? pin = _pin}) => PairedHost(
          id: 'deadbeef',
          name: 'desk',
          host: '192.168.1.10',
          port: 8787,
          tls: tls,
          certFingerprint: pin,
          lastConnected: DateTime.utc(2026, 1, 1),
        );

    test('uses wss when tls is on', () {
      expect(host().wsUrl, 'wss://192.168.1.10:8787/rpc');
      expect(host(tls: false, pin: null).wsUrl, 'ws://192.168.1.10:8787/rpc');
    });

    test('round-trips the pin through JSON', () {
      final decoded = PairedHost.fromJson(host().toJson());
      expect(decoded.certFingerprint, _pin);
      expect(decoded.tls, isTrue);
    });

    test('tolerates hosts saved before pinning existed', () {
      final legacy = host().toJson()..remove('certFingerprint');
      expect(PairedHost.fromJson(legacy).certFingerprint, isNull);
    });
  });

  group('QR pairing payload', () {
    String qr({bool tls = true, String? pin = _pin}) => jsonEncode({
          'v': 1,
          'kind': 'acoder',
          'host': '192.168.1.10',
          'port': 8787,
          'tls': tls,
          'token': 't' * 43,
          'name': 'desk',
          'id': 'deadbeef',
          if (pin != null) 'pin': pin,
        });

    test('parses tls + pin', () {
      final payload = QrPairingPayload.parse(qr());
      expect(payload, isNotNull);
      expect(payload!.tls, isTrue);
      expect(payload.pin, _pin);
    });

    test('plaintext payload has no pin', () {
      final payload = QrPairingPayload.parse(qr(tls: false, pin: null));
      expect(payload!.tls, isFalse);
      expect(payload.pin, isNull);
    });

    test('rejects malformed payloads', () {
      expect(QrPairingPayload.parse('not json'), isNull);
      expect(QrPairingPayload.parse('{"v":1,"kind":"nope"}'), isNull);
    });
  });
}
