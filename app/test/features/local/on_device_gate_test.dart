// THE-110: iOS v1 must not expose the on-device LFM3 surface.
//
// `app/pubspec.yaml` configures `llamadart` native backends for
// `android-arm64` and `android-x64` only, so an iOS build has no runtime to
// load. These tests drive the real route map and the home entry point on both
// platforms, and prove the iOS path constructs no local screen and never
// reaches `LlamaEngine.load`.

import 'package:acoder_mobile/app.dart';
import 'package:acoder_mobile/core/connection/connection_state.dart' as cs;
import 'package:acoder_mobile/core/connection/host_registry.dart';
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/local/local_chat_controller.dart';
import 'package:acoder_mobile/features/local/local_chat_screen.dart';
import 'package:acoder_mobile/features/local/local_model_store.dart';
import 'package:acoder_mobile/features/local/local_models_screen.dart';
import 'package:acoder_mobile/features/local/on_device_availability.dart';
import 'package:acoder_mobile/features/local/on_device_unavailable_screen.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:acoder_mobile/features/sessions/screens/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localRoutes = <String>[
  '/local',
  '/local/text',
  '/local/omni',
  '/local/voice',
];

const _hostId = 'host-the-110';

/// Disconnected from the wire: keeps the provider's real constructor but skips
/// `start()`, so Home renders a ready, empty session list.
class _FakeSessionController extends SessionController {
  _FakeSessionController(super.ref, super.hostId) {
    state = const SessionControllerState(
      connection: cs.ConnectionInfo(state: cs.ConnectionState.ready),
    );
  }

  @override
  Future<void> refreshSessions() async {}
}

/// Run [body] under [platform], restoring the override inside the test body so
/// flutter_test's foundation-variable invariant sees a clean value.
Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Pump a bare MaterialApp that uses the app's real route map.
Future<void> _pumpRouteHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PiTheme.dark,
      onGenerateRoute: appRouteFor,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final host = PairedHost(
    id: _hostId,
    name: 'Dev MacBook',
    host: '127.0.0.1',
    port: 4317,
    tls: false,
    lastConnected: DateTime(2026, 1, 1),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeHostProvider.overrideWith((ref) async => host),
        sessionControllerProvider.overrideWith(
          (ref, hostId) => _FakeSessionController(ref, hostId),
        ),
      ],
      child: MaterialApp(
        theme: PiTheme.dark,
        builder: (context, child) => PiColorsScope(
          skin: 'aurora',
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeScreen(activeHostId: _hostId),
      ),
    ),
  );
  // initState schedules the first sync in a microtask.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => LocalChatController.engineLoadAttempts = 0);

  test('only Android enables on-device models in v1', () {
    expect(onDeviceModelsAvailable(TargetPlatform.android), isTrue);
    expect(onDeviceModelsAvailable(TargetPlatform.iOS), isFalse);
    expect(onDeviceModelsAvailable(TargetPlatform.macOS), isFalse);
    expect(onDeviceModelsAvailable(TargetPlatform.fuchsia), isFalse);
    expect(onDeviceModelsAvailable(TargetPlatform.linux), isFalse);
    expect(onDeviceModelsAvailable(TargetPlatform.windows), isFalse);
  });

  group('iOS', () {
    testWidgets('every /local route renders the gate, never a local screen',
        (tester) async {
      await _withPlatform(TargetPlatform.iOS, () async {
        for (final name in _localRoutes) {
          await _pumpRouteHost(tester);
          tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(name);
          await tester.pumpAndSettle();

          expect(find.byType(OnDeviceUnavailableScreen), findsOneWidget,
              reason: name);
          expect(find.byType(LocalModelsScreen), findsNothing, reason: name);
          expect(find.byType(LocalChatScreen), findsNothing, reason: name);
          expect(find.textContaining('Android-only in v1'), findsOneWidget,
              reason: name);
        }

        // `LlamaEngine.load` lives only in `LocalChatController.loadModel`;
        // the route gate must not reach it.
        expect(LocalChatController.engineLoadAttempts, 0,
            reason: 'the iOS gate must never attempt a llamadart load');
      });
    });

    testWidgets('route builders return the gate for every /local route',
        (tester) async {
      await _withPlatform(TargetPlatform.iOS, () async {
        await _pumpRouteHost(tester);
        final context = tester.element(find.byType(Scaffold));

        for (final name in _localRoutes) {
          final route = appRouteFor(RouteSettings(name: name))!
              as MaterialPageRoute<void>;
          expect(route.builder(context), isA<OnDeviceUnavailableScreen>(),
              reason: name);
        }
      });
    });

    testWidgets('home hides the on-device icon', (tester) async {
      await _withPlatform(TargetPlatform.iOS, () async {
        await _pumpHome(tester);

        expect(find.byTooltip('On-device chat'), findsNothing);
        expect(find.byIcon(Icons.memory_outlined), findsNothing);
      });
    });
  });

  group('Android', () {
    testWidgets('route builders resolve to the real on-device screens',
        (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        await _pumpRouteHost(tester);
        final context = tester.element(find.byType(Scaffold));

        final hub = appRouteFor(const RouteSettings(name: '/local'))!
            as MaterialPageRoute<void>;
        expect(hub.builder(context), isA<LocalModelsScreen>());

        final expected = <String, LocalModelSpec>{
          '/local/text': LocalModelCatalog.text,
          '/local/omni': LocalModelCatalog.omni,
          '/local/voice': LocalModelCatalog.voice,
        };
        expected.forEach((routeName, spec) {
          final route = appRouteFor(RouteSettings(name: routeName))!
              as MaterialPageRoute<void>;
          final screen = route.builder(context);
          expect(screen, isA<LocalChatScreen>(), reason: routeName);
          expect((screen as LocalChatScreen).spec.id, spec.id,
              reason: routeName);
        });
      });
    });

    testWidgets('home keeps the on-device icon', (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        await _pumpHome(tester);

        expect(find.byTooltip('On-device chat'), findsOneWidget);
        expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
      });
    });
  });
}
