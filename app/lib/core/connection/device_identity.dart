// lib/core/connection/device_identity.dart
library;

/// Stable per-install device identity presented to the bridge on the WS
/// upgrade (`plan/04-bridge-spec.md` §5.4).
///
/// The bridge keeps one registry record per device that identifies itself and
/// admits a device only while that record exists. A client that presents no
/// id still connects on the pairing token, but **never appears in the
/// registry** — so the desktop's Settings → Mobile access card shows no
/// devices. That is exactly the v1.0.0-rc1 defect the operator hit on hardware
/// (Nothing Phone 2a, Android 17, 2026-11-26): the app opened the socket with
/// only `Authorization`, so `serve/clients.json` was never written.
///
/// The id is generated once per install and reused for the life of the app
/// data. It is not a credential (the pairing token is), so it lives in
/// `shared_preferences` rather than the secure store: it must be readable
/// before the first connect and it survives app updates.
import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// What the bridge reads back out of `x-acoder-device-*`.
///
/// Constraints from `serve/clients.ts`: id must match
/// `[A-Za-z0-9._:-]{1,128}`, name is capped at 64 chars, platform at 32.
class DeviceIdentity {
  final String id;
  final String name;
  final String platform;

  const DeviceIdentity({
    required this.id,
    required this.name,
    required this.platform,
  });

  /// Upgrade headers for `RpcClient`. Header identity is the only path the
  /// bridge can refuse with a pre-upgrade 401, so it is the one we use.
  Map<String, String> get headers => {
        'x-acoder-device-id': id,
        'x-acoder-device-name': name,
        'x-acoder-device-platform': platform,
      };

  @override
  String toString() => 'DeviceIdentity($id, $name, $platform)';
}

/// Persists and loads the device identity.
///
/// Failure is never fatal: if preferences are unavailable (plugin missing in
/// a test host, storage error) the store returns a session-only identity so
/// the connection still identifies itself to the bridge — the record then
/// exists for that install run, it just cannot be reused next launch.
class DeviceIdentityStore {
  static const idKey = 'device_identity_id';
  static const nameKey = 'device_identity_name';

  /// Accepted by `normalizeDeviceId` in `serve/clients.ts`.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');

  final SharedPreferences? _prefsOverride;
  Future<SharedPreferences>? _prefsFuture;
  final Uuid _uuid;

  DeviceIdentityStore({
    SharedPreferences? prefs,
    SharedPreferences? preferences,
    Future<SharedPreferences>? sharedPreferences,
    Uuid? uuid,
  })  : _prefsOverride = prefs ?? preferences,
        _uuid = uuid ?? const Uuid() {
    if (sharedPreferences != null) _prefsFuture = sharedPreferences;
  }

  Future<SharedPreferences?> _prefsOrNull() async {
    try {
      if (_prefsOverride != null) return _prefsOverride;
      final f = _prefsFuture;
      if (f != null) return await f;
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Load the identity, generating and persisting one on first run (or when
  /// the stored id would be rejected by the bridge).
  Future<DeviceIdentity> load() async {
    final platform = _platform();
    final prefs = await _prefsOrNull();

    final stored = prefs?.getString(idKey);
    final id = stored != null && _idPattern.hasMatch(stored)
        ? stored
        : _newId();
    if (prefs != null && id != stored) {
      try {
        await prefs.setString(idKey, id);
      } catch (_) {
        // Non-fatal: this install just re-identifies next launch.
      }
    }

    final storedName = prefs?.getString(nameKey);
    final name = (storedName != null && storedName.trim().isNotEmpty)
        ? storedName.trim()
        : _defaultName(platform, id);
    return DeviceIdentity(id: id, name: name, platform: platform);
  }

  /// Rename this device (shown in the desktop Mobile access card).
  Future<DeviceIdentity> rename(String name) async {
    final identity = await load();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return identity;
    final prefs = await _prefsOrNull();
    try {
      await prefs?.setString(nameKey, trimmed.substring(0, trimmed.length > 64 ? 64 : trimmed.length));
    } catch (_) {
      // Rename is cosmetic; the connection still uses the generated name.
    }
    return DeviceIdentity(
      id: identity.id,
      name: trimmed.length > 64 ? trimmed.substring(0, 64) : trimmed,
      platform: identity.platform,
    );
  }

  String _newId() => 'mobile-${_uuid.v4()}';

  static String _platform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // `Platform` is unavailable on web builds; treated as unknown.
    }
    return 'unknown';
  }

  /// We ship no device-model plugin, so the label cannot be "Pixel 9". Keep it
  /// honest and disambiguated: two Android phones in one registry must not
  /// look identical.
  static String _defaultName(String platform, String id) {
    final label = switch (platform) {
      'android' => 'Android phone',
      'ios' => 'iPhone',
      'macos' => 'Mac',
      'windows' => 'Windows PC',
      'linux' => 'Linux PC',
      _ => 'Mobile device',
    };
    final suffix = id.replaceAll('mobile-', '');
    final short = suffix.length >= 4 ? suffix.substring(0, 4) : suffix;
    return short.isEmpty ? label : '$label ($short)';
  }
}
