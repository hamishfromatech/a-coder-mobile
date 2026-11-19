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

import 'core/notifications/notification_service.dart';
import 'design/theme.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/pairing/providers/connection_providers.dart';
import 'features/pairing/screens/pairing_screen.dart';
import 'features/splash/connecting_overlay.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/model_picker_screen.dart';
import 'features/cron/screens/cron_screen.dart';
import 'features/office/screens/office_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/local/local_chat_screen.dart';
import 'features/local/local_models_screen.dart';
import 'features/local/local_model_store.dart';
import 'features/local/on_device_availability.dart';
import 'features/local/on_device_unavailable_screen.dart';
import 'features/shell/screens/app_shell.dart';

class ACoderApp extends ConsumerStatefulWidget {
  const ACoderApp({super.key});

  @override
  ConsumerState<ACoderApp> createState() => _ACoderAppState();
}

class _ACoderAppState extends ConsumerState<ACoderApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastReconnectAt;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onNetworkChange);
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
    NotificationService.instance.appInForeground =
        state == AppLifecycleState.resumed;
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
        ref
            .read(sessionControllerProvider(hostId).notifier)
            .forceReconnectNow();
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
    final settings = ref.watch(settingsProvider);
    NotificationService.instance.configure(settings);
    return MaterialApp(
      title: 'A-Coder',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: PiTheme.lightFor(settings.skin),
      darkTheme: PiTheme.darkFor(settings.skin),
      themeMode: settings.themeMode, // dark-first default (doc 09)
      // Refresh the static token set for the selected skin + brightness before
      // the app subtree builds, so every `PiColors.x` call site follows it.
      builder: (context, child) => PiColorsScope(
        skin: settings.skin,
        child: child ?? const SizedBox.shrink(),
      ),
      onGenerateRoute: appRouteFor,
      home: const _HomeGate(),
    );
  }
}

/// Route map (doc 06), top-level so widget tests can drive the real map
/// without constructing the plugin-touching app shell.
///
/// /                     → gate: no hosts → Pairing; else → Home
/// /pair                 → Pairing screen
/// /home                 → Session list + status header
/// /chat                 → Chat screen (arguments: {hostId, sessionPath})
/// /model                → Model picker (modal)
/// /local*               → On-device hub/chat (Android only in v1, THE-110)
/// /settings             → Connection mgmt, appearance, about
Route<dynamic>? appRouteFor(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute<void>(
          settings: settings, builder: (_) => const _HomeGate());
    case '/pair':
      return MaterialPageRoute<void>(
          settings: settings, builder: (_) => const PairingScreen());
    case '/home':
      final args = settings.arguments as Map<String, String>? ?? {};
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AppShell(activeHostId: args['hostId'] ?? ''),
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
      return MaterialPageRoute<void>(
          settings: settings, builder: (_) => const ModelPickerScreen());
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
    case '/local':
      return _onDeviceRoute(settings, () => const LocalModelsScreen());
    case '/local/text':
      return _onDeviceRoute(
          settings, () => const LocalChatScreen(spec: LocalModelCatalog.text));
    case '/local/omni':
      return _onDeviceRoute(
          settings, () => const LocalChatScreen(spec: LocalModelCatalog.omni));
    case '/local/voice':
      return _onDeviceRoute(
          settings, () => const LocalChatScreen(spec: LocalModelCatalog.voice));
    case '/settings':
      return MaterialPageRoute<void>(
          settings: settings, builder: (_) => const SettingsScreen());
    default:
      return null;
  }
}

/// On-device routes resolve to their screen only where a `llamadart` native
/// runtime exists (Android in v1). Everywhere else the route stays reachable
/// but renders the gate, and [screen] is never called — so neither
/// `LocalModelsScreen`/`LocalChatScreen` nor a `llamadart` load is constructed.
Route<dynamic>? _onDeviceRoute(
    RouteSettings settings, Widget Function() screen) {
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => onDeviceModelsAvailable()
        ? screen()
        : const OnDeviceUnavailableScreen(),
  );
}

/// Route gate: loading → spinner; no host → Pairing; else → Home.
/// Watches activeHostProvider so pairing/forget instantly re-gates.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(activeHostProvider);
    return hostAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const PairingScreen(),
      data: (host) {
        if (host == null) return const PairingScreen();
        // Keep the connection stack alive as long as a host is active.
        ref.watch(sessionControllerProvider(host.id));
        // Cold-boot splash: covers the shell while the bridge connects for the
        // first time, plays the exit choreography on ready, never resurrects.
        return Stack(
          children: [
            AppShell(activeHostId: host.id),
            ConnectingOverlay(hostId: host.id),
          ],
        );
      },
    );
  }
}
