// lib/main.dart
library;

/// Entry point — bootstraps Riverpod and runs the app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/connection/host_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug helper: pre-seed a paired host from --dart-define flags so the app
  // can be smoke-tested on desktop/CI without scanning a QR code, e.g.
  //   flutter run --dart-define=SEED_HOST_IP=127.0.0.1 \
  //               --dart-define=SEED_HOST_PORT=8801 \
  //               --dart-define=SEED_HOST_TOKEN=<token>
  const seedIp = String.fromEnvironment('SEED_HOST_IP');
  const seedPort = int.fromEnvironment('SEED_HOST_PORT', defaultValue: 8787);
  const seedToken = String.fromEnvironment('SEED_HOST_TOKEN');
  if (seedIp.isNotEmpty && seedToken.isNotEmpty) {
    final registry = HostRegistry();
    const id = 'debug-host';
    await registry.saveHost(
      PairedHost(
        id: id,
        name: 'Debug bridge',
        host: seedIp,
        port: seedPort,
        tls: false,
        lastConnected: DateTime.now(),
      ),
      seedToken,
    );
    // ignore: avoid_print
    print('[seed] debug host saved: $seedIp:$seedPort');
    await registry.setActiveHost(id);
  }

  runApp(const ProviderScope(child: ACoderApp()));
}
