// lib/core/connection/host_registry.dart
library;
/// Paired hosts CRUD — tokens in secure storage (Keychain/Keystore),
/// non-secret host metadata in shared_preferences (doc 04 §5.3).
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
class PairedHost {
  final String id; // machine ID from QR (SHA-256(token) first 8 hex chars)
  final String name; // friendly name ("Hamish's MacBook")
  final String host; // IP address or hostname
  final int port; // WebSocket port
  final bool tls; // wss:// vs ws://
  /// SHA-256 certificate pin for wss:// (lowercase hex, optional).
  final String? certFingerprint;
  final DateTime lastConnected;
  const PairedHost({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.tls,
    this.certFingerprint,
    required this.lastConnected,
  });
  String get wsUrl => '${tls ? 'wss' : 'ws'}://$host:$port/rpc';
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'tls': tls,
        if (certFingerprint != null) 'certFingerprint': certFingerprint,
        'lastConnected': lastConnected.toIso8601String(),
      };
  factory PairedHost.fromJson(Map<String, dynamic> json) => PairedHost(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        host: json['host'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 0,
        tls: json['tls'] as bool? ?? false,
        certFingerprint: json['certFingerprint'] as String?,
        lastConnected: json['lastConnected'] is String
            ? DateTime.tryParse(json['lastConnected'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
  PairedHost copyWith(
      {String? name, String? host, int? port, bool? tls, String? certFingerprint}) {
    return PairedHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      tls: tls ?? this.tls,
      certFingerprint: certFingerprint ?? this.certFingerprint,
      lastConnected: lastConnected,
    );
  }
}
class HostRegistry {
  static const _prefKey = 'paired_hosts'; // JSON list of host metadata
  static const _activeKey = 'active_host_id';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences? _prefsOverride;
  Future<SharedPreferences>? _prefsFuture;

  HostRegistry({
    FlutterSecureStorage? secureStorage,
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
    SharedPreferences? preferences,
    Future<SharedPreferences>? sharedPreferences,
  })  : _secureStorage = secureStorage ?? storage ?? const FlutterSecureStorage(),
        _prefsOverride = prefs ?? preferences {
    if (sharedPreferences != null) _prefsFuture = sharedPreferences;
  }

  Future<SharedPreferences> _prefs() async {
    if (_prefsOverride != null) return _prefsOverride;
    final f = _prefsFuture;
    if (f != null) return f;
    return SharedPreferences.getInstance();
  }

  Future<T> _safeSecure<T>(Future<T> Function() op, T fallback) async {
    try {
      return await op();
    } catch (_) {
      // Missing secure-storage plugin or platform error: degrade gracefully.
      return fallback;
    }
  }

  /// All paired hosts, most recent first.
  Future<List<PairedHost>> getHosts() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      final result = <PairedHost>[];
      for (final entry in decoded) {
        if (entry is Map) {
          try {
            result.add(PairedHost.fromJson(Map<String, dynamic>.from(entry)));
          } catch (_) {
            // Skip corrupt entries.
          }
        }
      }
      result.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
      return result;
    } catch (_) {
      // Corrupt/partial JSON tolerance: clear and start fresh.
      try {
        await prefs.remove(_prefKey);
      } catch (_) {}
      return [];
    }
  }
  /// Get a specific host by ID.
  Future<PairedHost?> getHost(String id) async {
    final hosts = await getHosts();
    for (final h in hosts) {
      if (h.id == id) return h;
    }
    return null;
  }
  /// Save a paired host (token in secure storage, metadata in prefs).
  Future<void> saveHost(PairedHost host, String token) async {
    // Secret: bearer token goes to secure storage only (never logged).
    await _safeSecure(() => _secureStorage.write(key: 'token_${host.id}', value: token), null);
    // Non-secret: upsert host metadata atomically as one JSON value.
    final prefs = await _prefs();
    final hosts = await getHosts();
    final updated = hosts.where((h) => h.id != host.id).toList()..add(host);
    try {
      await prefs.setString(_prefKey, jsonEncode(updated.map((h) => h.toJson()).toList()));
    } catch (_) {
      // Tolerate storage failures for metadata.
    }
  }
  /// Get the token for a paired host (from secure storage).
  Future<String?> getToken(String hostId) async {
    return _safeSecure(() => _secureStorage.read(key: 'token_$hostId'), null);
  }
  /// Remove a paired host (metadata + token).
  Future<void> removeHost(String id) async {
    final prefs = await _prefs();
    final hosts = await getHosts();
    final updated = hosts.where((h) => h.id != id).toList();
    try {
      await prefs.setString(_prefKey, jsonEncode(updated.map((h) => h.toJson()).toList()));
    } catch (_) {}
    await prefs.remove('host_meta_$id');
    await prefs.remove('host_data_$id');
    await _safeSecure(() => _secureStorage.delete(key: 'token_$id'), null);
    final active = await getActiveHostId();
    if (active == id) {
      if (updated.isNotEmpty) {
        try {
          await prefs.setString(_activeKey, updated.first.id);
        } catch (_) {}
      } else {
        try {
          await prefs.remove(_activeKey);
        } catch (_) {}
      }
    }
  }
  /// Set the active host (the one to connect to).
  Future<void> setActiveHost(String id) async {
    final prefs = await _prefs();
    try {
      await prefs.setString(_activeKey, id);
    } catch (_) {}
  }
  /// Get the active host ID, with fallback to the most recent host.
  Future<String?> getActiveHostId() async {
    final prefs = await _prefs();
    final hosts = await getHosts();
    if (hosts.isEmpty) {
      try {
        await prefs.remove(_activeKey);
      } catch (_) {}
      return null;
    }
    final stored = prefs.getString(_activeKey);
    if (stored != null && hosts.any((h) => h.id == stored)) {
      return stored;
    }
    // Fallback to most recently connected host.
    final fallback = hosts.first.id;
    try {
      await prefs.setString(_activeKey, fallback);
    } catch (_) {}
    return fallback;
  }
  /// Get the active host, if any.
  Future<PairedHost?> getActiveHost() async {
    final id = await getActiveHostId();
    if (id == null) return null;
    return getHost(id);
  }
}
