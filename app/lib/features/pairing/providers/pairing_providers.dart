// lib/features/pairing/providers/pairing_providers.dart
library;
/// Pairing state providers — QR payload parsing, host registration, connection setup.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connection/host_registry.dart';
final hostsProvider = StateNotifierProvider<HostsNotifier, List<PairedHost>>((ref) {
  return HostsNotifier();
});
class HostsNotifier extends StateNotifier<List<PairedHost>> {
  final _registry = HostRegistry();
  HostsNotifier() : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await _registry.getHosts();
  }
  Future<void> addHost(PairedHost host, String token) async {
    await _registry.saveHost(host, token);
    await _load();
  }
  Future<void> removeHost(String id) async {
    await _registry.removeHost(id);
    await _load();
  }
  Future<void> setActive(String id) async {
    await _registry.setActiveHost(id);
  }
}
