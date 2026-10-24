// lib/features/pairing/screens/pairing_screen.dart
library;
/// First-run pairing screen (doc 06 §1).
/// Segmented control: Scan QR / Manual / On this network.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connection/host_registry.dart';
import '../../../design/theme.dart';
import '../../../design/components/status_dot.dart';
import '../providers/pairing_providers.dart';
import '../providers/connection_providers.dart';
enum PairingTab { scan, manual, discover }
/// Parsed QR payload (doc 04 §5.2) — mirrors the bridge's parseQrPayload.
class QrPairingPayload {
  final String host;
  final int port;
  final bool tls;
  final String token;
  final String name;
  final String id;
  const QrPairingPayload({
    required this.host,
    required this.port,
    required this.tls,
    required this.token,
    required this.name,
    required this.id,
  });
  static QrPairingPayload? parse(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map<String, dynamic>) return null;
      if (obj['v'] != 1 || obj['kind'] != 'acoder') return null;
      final host = obj['host'] as String? ?? '';
      final port = (obj['port'] as num?)?.toInt() ?? 0;
      final token = obj['token'] as String? ?? '';
      if (host.isEmpty || port <= 0 || token.length < 32) return null;
      return QrPairingPayload(
        host: host,
        port: port,
        tls: obj['tls'] as bool? ?? false,
        token: token,
        name: obj['name'] as String? ?? '',
        id: obj['id'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});
  @override ConsumerState<PairingScreen> createState() => _PairingScreenState();
}
class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController _camera = MobileScannerController();
  bool _handledLatest = true; // debounce duplicate detections
  String? _errorMessage;
  // Manual entry fields — token renders as groups of 8 (5×8 + 4 for 44 chars).
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8787');
  final _tokenControllers = List<TextEditingController>.generate(6, (_) => TextEditingController());
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() {
    _camera.dispose();
    _hostController.dispose();
    _portController.dispose();
    for (final c in _tokenControllers) {
      c.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }
  /// Handle QR code detection (mobile_scanner 7.x API).
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || !_handledLatest) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final payload = QrPairingPayload.parse(raw);
      if (payload == null) {
        setState(() => _errorMessage = 'Invalid QR code — not an A-Coder pairing code');
        continue;
      }
      _handledLatest = false;
      final confirmed = await _confirmPayload(payload);
      _handledLatest = true;
      if (confirmed && mounted) {
        await _saveAndEnter(payload.host, payload.port, payload.tls, payload.token, payload.name,
            id: payload.id.isNotEmpty ? payload.id : null);
      }
      break;
    }
  }
  /// Persist the paired host (token → secure storage) and re-gate the app.
  Future<void> _saveAndEnter(String host, int port, bool tls, String token, String name, {String? id}) async {
    final paired = PairedHost(
      id: id ?? const Uuid().v4(), // QR carries the machine id; manual entry generates one
      name: name.isEmpty ? '$host:$port' : name,
      host: host,
      port: port,
      tls: tls,
      lastConnected: DateTime.now(),
    );
    await ref.read(hostsProvider.notifier).addHost(paired, token);
    await ref.read(hostsProvider.notifier).setActive(paired.id);
    // Re-gate: activeHostProvider refreshes → app shows Home + connects.
    ref.invalidate(activeHostIdProvider);
    ref.invalidate(activeHostProvider);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home', arguments: {'hostId': paired.id});
    }
  }

  /// Confirmation sheet before trusting the scanned token (doc 04 §5.2).

  Future<bool> _confirmPayload(QrPairingPayload payload) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pair with this machine?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                payload.name.isEmpty ? '${payload.host}:${payload.port}' : '${payload.name} — ${payload.host}:${payload.port}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scanning = trust: the QR contains the pairing token. Only pair with machines you control.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Connect'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }
  /// Handle manual entry connect.
  Future<void> _handleManualConnect() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8787;
    final token = _tokenControllers.map((c) => c.text.trim()).join('');
    if (host.isEmpty || token.length < 32) {
      setState(() => _errorMessage = 'Enter a valid host and full token (43 chars)');
      return;
    }
    await _saveAndEnter(host, port, false, token, 'Manual — $host');
  }
  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair with A-Coder'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.keyboard), text: 'Manual'),
            Tab(icon: Icon(Icons.wifi), text: 'Network'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanTab(),
          _buildManualTab(c),
          _buildDiscoverTab(c),
        ],
      ),
    );
  }
  Widget _buildScanTab() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
              ),
              // QR reticle overlay
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: PiColors.accent, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_errorMessage != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PiColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 13, color: PiColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Torch toggle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _camera.toggleTorch(),
            color: PiColors.accent,
          ),
        ),
      ],
    );
  }
  Widget _buildManualTab(PiPalette c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Host (IP or hostname)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
            const SizedBox(height: 24),
            Text('Pairing token', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: _tokenControllers.map((ctrl) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.text,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '--------',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              'Copy the "Pairing token" groups from the serve banner (5 groups of 8 + 1 of 4).',
              style: TextStyle(fontSize: 11, color: c.textFaint),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: PiColors.error, fontSize: 13)),
              ),
            ElevatedButton(
              onPressed: _handleManualConnect,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 8),
            Text(
              'Check that serve is running on the desktop (a-coder-cli serve)',
              style: TextStyle(fontSize: 12, color: c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildDiscoverTab(PiPalette c) {
    // bonsoir mDNS discovery of _a-coder._tcp services (wired in M4).
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.wifi_rounded, size: 48, color: c.textFaint),
          const SizedBox(height: 16),
          Text(
            'Scanning for A-Coder on this network...',
            style: TextStyle(fontSize: 15, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure the desktop is running `a-coder-cli serve`.\nTap a device below to connect.',
            style: TextStyle(fontSize: 13, color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [StatusDot(type: StatusDotType.live)],
                ),
                const SizedBox(height: 8),
                Text(
                  'No devices found',
                  style: TextStyle(color: c.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Discovery shows available devices. You still need to enter the pairing token.',
            style: TextStyle(fontSize: 12, color: c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}