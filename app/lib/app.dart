// lib/app.dart
library;
/// MaterialApp configuration: theme (dark-first, doc 09), route map (doc 06),
/// and app lifecycle + connectivity observers for reconnect-on-resume.
/// Wired in M3: active host via providers; resume/network change triggers a
/// guarded forceReconnect on the live SessionController.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/theme.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/pairing/providers/connection_providers.dart';
import 'features/pairing/screens/pairing_screen.dart';
import 'features/sessions/screens/home_screen.dart';
import 'features/splash/connecting_overlay.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/model_picker_screen.dart';
import 'features/cron/screens/cron_screen.dart';
import 'features/office/screens/office_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class ACoderApp extends ConsumerStatefulWidget {
  const ACoderApp({super.key});

  @override
  ConsumerState<ACoderApp> createState() => _ACoderAppState();
}

class _ACoderAppState extends ConsumerState<ACoderApp> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastReconnectAt;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onNetworkChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  /// App resume from background → force reconnect (guarded: no-op when healthy).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnectActive();
    }
  }

  /// Network change → trigger reconnect.
  void _onNetworkChange(List<ConnectivityResult> results) {
    if (results.any((r) => r != ConnectivityResult.none)) {
      _reconnectActive();
    }
  }

  /// Delegates reconnection to the connection layer. Coalesces resume and
  /// network-change events that arrive within [_reconnectWindow] so the
  /// connection stack only does the work once.
  static const _reconnectWindow = Duration(seconds: 2);

  void _reconnectActive() {
    final now = DateTime.now();
    if (_reconnecting) return;
    if (_lastReconnectAt != null &&
        now.difference(_lastReconnectAt!) < _reconnectWindow) {
      return;
    }
    _reconnecting = true;
    _lastReconnectAt = now;
    try {
      final hostId = ref.read(activeHostIdProvider).value;
      if (hostId != null) {
        ref.read(sessionControllerProvider(hostId).notifier).forceReconnectNow();
      }
    } finally {
      // Reset after a short window; the connection layer owns actual reconnect.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _reconnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'A-Coder',
      debugShowCheckedModeBanner: false,
      theme: PiTheme.light,
      darkTheme: PiTheme.dark,
      themeMode: themeMode, // dark-first default (doc 09), user-overridable
      // ─── Route map (doc 06) ──────────────────────────────────
      // /                     → gate: no hosts → Pairing; else → Home
      // /pair                 → Pairing screen
      // /home                 → Session list + status header
      // /chat/:hostId         → Chat screen (arguments: {hostId, sessionPath})
      // /model                → Model picker (modal)
      // /settings             → Connection mgmt, appearance, about
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const _HomeGate());
          case '/pair':
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const PairingScreen());
          case '/home':
            final args = settings.arguments as Map<String, String>? ?? {};
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => HomeScreen(activeHostId: args['hostId'] ?? ''),
            );
          case '/chat':
            final args = settings.arguments as Map<String, String>? ?? {};
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ChatScreen(
                hostId: args['hostId'] ?? '',
                sessionPath: args['sessionPath'],
              ),
            );
          case '/model':
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const ModelPickerScreen());
          case '/cron':
            final args = settings.arguments as Map<String, String>? ?? {};
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CronScreen(hostId: args['hostId'] ?? ''),
            );
          case '/office':
            final args = settings.arguments as Map<String, String>? ?? {};
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => OfficeScreen(hostId: args['hostId'] ?? ''),
            );
          case '/settings':
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const SettingsScreen());
          default:
            return null;
        }
      },
      home: const _HomeGate(),
    );
  }
}

/// Route gate: loading → spinner; no host → Pairing; else → Home.
/// Watches activeHostProvider so pairing/forget instantly re-gates.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(activeHostProvider);
    return hostAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const PairingScreen(),
      data: (host) {
        if (host == null) return const PairingScreen();
        // Keep the connection stack alive as long as a host is active.
        ref.watch(sessionControllerProvider(host.id));
        // Cold-boot splash: covers the shell while the bridge connects for the
        // first time, plays the exit choreography on ready, never resurrects.
        return Stack(
          children: [
            HomeScreen(activeHostId: host.id),
            ConnectingOverlay(hostId: host.id),
          ],
        );
      },
    );
  }
}
