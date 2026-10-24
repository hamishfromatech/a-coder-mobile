// Certificate pinning for wss:// bridges (plan M6.3).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Normalize a SHA-256 fingerprint so `AA:BB:…`, `aabb…` and spaced forms all
/// compare equal.
String normalizeFingerprint(String value) =>
    value.replaceAll(':', '').replaceAll(' ', '').toLowerCase();

/// True when the certificate's SHA-256 hex digest matches the paired pin.
bool matchesPinnedFingerprint(String actualHex, String pin) =>
    pin.trim().isNotEmpty &&
    normalizeFingerprint(actualHex) == normalizeFingerprint(pin);

/// SHA-256 (lowercase hex) of DER-encoded certificate bytes.
String fingerprintOfDer(List<int> der) => sha256.convert(der).toString();

/// Validate a fingerprint supplied out of band (QR / manual entry).
/// Accepts 64 hex chars, optionally colon-separated. Returns the normalized
/// value, or null when malformed.
String? parseFingerprint(String? raw) {
  if (raw == null) return null;
  final normalized = normalizeFingerprint(raw);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) return null;
  return normalized;
}

/// Best-effort helper for logs/tests: never include the raw pin in telemetry.
String redactFingerprint(String pin) {
  final normalized = normalizeFingerprint(pin);
  if (normalized.length < 12) return '***';
  return '${normalized.substring(0, 8)}…';
}

/// Decode a PEM certificate body to DER (needed only when a caller has to
/// compare against PEM material rather than a live handshake).
List<int>? derFromPem(String pem) {
  final match = RegExp(
    r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----',
  ).firstMatch(pem);
  if (match == null) return null;
  try {
    return base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
  } catch (_) {
    return null;
  }
}
