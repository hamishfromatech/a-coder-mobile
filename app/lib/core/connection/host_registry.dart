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
  final DateTime lastConnected;
  const PairedHost({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.tls,
    required this.lastConnected,
  });
  String get wsUrl => '${tls ? 'wss' : 'ws'}://$host:$port/rpc';
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'tls': tls,
        'lastConnected': lastConnected.toIso8601String(),
      };
  factory PairedHost.fromJson(Map<String, dynamic> json) => PairedHost(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        host: json['host'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 0,
        tls: json['tls'] as bool? ?? false,
        lastConnected: json['lastConnected'] is String
            ? DateTime.tryParse(json['lastConnected'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
  PairedHost copyWith({String? name, String? host, int? port, bool? tls}) {
    return PairedHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      tls: tls ?? this.tls,
      lastConnected: lastConnected,
    );
  }
}
class HostRegistry {
  static const _secureStorage = FlutterSecureStorage();
  static const _prefKey = 'paired_hosts'; // JSON list of host metadata
  static const _activeKey = 'active_host_id';
  /// All paired hosts, most recent first.
  Future<List<PairedHost>> getHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PairedHost.fromJson)
          .toList();
      list.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
      return list;
    } catch (_) {
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
    // Secret: bearer token goes to secure storage only.
    await _secureStorage.write(key: 'token_${host.id}', value: token);
    // Non-secret: upsert host metadata.
    final prefs = await SharedPreferences.getInstance();
    final hosts = await getHosts();
    final updated = hosts.where((h) => h.id != host.id).toList()..add(host);
    await prefs.setString(_prefKey, jsonEncode(updated.map((h) => h.toJson()).toList()));
  }
  /// Get the token for a paired host (from secure storage).
  Future<String?> getToken(String hostId) async {
    return _secureStorage.read(key: 'token_$hostId');
  }
  /// Remove a paired host (metadata + token).
  Future<void> removeHost(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final hosts = await getHosts();
    final updated = hosts.where((h) => h.id != id).toList();
    await prefs.setString(_prefKey, jsonEncode(updated.map((h) => h.toJson()).toList()));
    await prefs.remove('host_meta_$id');
    await prefs.remove('host_data_$id');
    await _secureStorage.delete(key: 'token_$id');
    if (await getActiveHostId() == id) {
      await prefs.remove(_activeKey);
    }
  }
  /// Set the active host (the one to connect to).
  Future<void> setActiveHost(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }
  /// Get the active host ID.
  Future<String?> getActiveHostId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }
}