// Widget tests for the Settings surface (appearance, alerts, about tabs) driven
// through the injectable settings-store seam — see
// settings_providers.dart `settingsProviderWith`. These render the real
// SettingsScreen with isolated in-memory prefs instead of the app-wide
// SharedPreferences singleton, so the sections can be exercised without a
// platform-specific prefs backend.

import 'dart:convert' show jsonEncode;

import 'package:acoder_mobile/core/connection/host_registry.dart';
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:acoder_mobile/features/settings/providers/settings_providers.dart';
import 'package:acoder_mobile/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/load_fonts.dart';

const hostId = 'h1';

PairedHost _sampleHost() => PairedHost(
      id: hostId,
      name: 'Hamish MacBook',
      host: '192.168.1.10',
      port: 8787,
      tls: false,
      lastConnected: DateTime.now(),
    );

/// Build the provider overrides the SettingsScreen needs when driven in a
/// widget test: a session controller that does not open a connection, and the
/// settings store backed by the given in-memory prefs.
List<Override> _settingsOverrides({SharedPreferences? prefs}) {
  return <Override>[
    // SettingsScreen's session tab reads the live session controller per
    // host; a real controller would open a connection, so override the
    // provider with a controller built without starting it.
    sessionControllerProvider.overrideWith(
      (ref, hostId) => SessionController(ref, hostId),
    ),
    settingsProvider.overrideWith((ref) => SettingsNotifier(prefs: prefs)),
  ];
}

void _seedInMemoryPrefs({Map<String, Object>? extra = const {}}) {
  final store = <String, Object>{
    ...(extra ?? {}),
    'paired_hosts': jsonEncode([_sampleHost().toJson()]),
    'active_host_id': hostId,
  };
  SharedPreferences.setMockInitialValues(store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFonts);

  testWidgets(
      'settings_screen renders appearance, alerts and about tabs with in-memory prefs',
      (tester) async {
    _seedInMemoryPrefs();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    final prefs = await SharedPreferences.getInstance();
    final overrides = _settingsOverrides(prefs: prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: PiTheme.dark,
          builder: (context, child) => PiColorsScope(
            skin: 'aurora',
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byType(SettingsScreen), findsOneWidget);
    // The default tab is Machines; switch to Appearance and About so their
    // sections render (only the selected tab's body is shown).
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    // Appearance sections render with the seam-backed settings store.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('SKIN'), findsOneWidget);
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('CHAT TEXT SIZE'), findsOneWidget);
    // Alerts renders from the same injected store (no permission prompt is
    // requested until the master toggle is tapped, so this stays platform-free).
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Approvals needed'), findsOneWidget);
    // Six tabs in a scrollable bar: ensure the target tab is actually on
    // screen before tapping, otherwise the tap lands off-viewport.
    await tester.ensureVisible(find.text('About'));
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('A-Coder Mobile'), findsOneWidget);
  });

  testWidgets('appearance settings persist through the injectable seam',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _settingsOverrides(prefs: prefs),
        child: MaterialApp(theme: PiTheme.dark, home: const SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    // Read the notifier the screen is actually bound to (the overridden
    // `settingsProvider`). `settingsProviderWith()` returns a *new* provider
    // object per call, so reading that here would drive a detached notifier and
    // leave the widget tree untouched.
    final notifier = container.read(settingsProvider.notifier);

    await notifier.setTheme(ThemePref.light);
    expect(notifier.state.theme, ThemePref.light);

    await notifier.setSkin('aurora');
    expect(notifier.state.skin, 'aurora');

    await notifier.setChatTextSize(16);
    expect(notifier.state.chatTextSize, 16);

    await notifier.setHaptics(false);
    expect(notifier.state.haptics, false);

    await notifier.setChatBackdrop(false);
    expect(notifier.state.chatBackdrop, false);

    await notifier.setNotificationsEnabled(true);
    expect(notifier.state.notificationsEnabled, true);

    await notifier.setAlertApprovals(false);
    expect(notifier.state.alertApprovals, false);

    await notifier.setAlertWhileForeground(true);
    expect(notifier.state.alertWhileForeground, true);

    expect(prefs.getInt('theme'), ThemePref.light.index);
    expect(prefs.getString('skin'), 'aurora');
    expect(prefs.getDouble('chatTextSize'), 16.0);
    expect(prefs.getBool('haptics'), false);
    expect(prefs.getBool('chatBackdrop'), false);
    expect(prefs.getBool('notificationsEnabled'), true);
    expect(prefs.getBool('alertApprovals'), false);
    expect(prefs.getBool('alertWhileForeground'), true);
  });

  testWidgets('notification settings persist through the injectable seam',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _settingsOverrides(prefs: prefs),
        child: MaterialApp(theme: PiTheme.dark, home: const SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    // Same rule as the appearance test: drive the notifier the screen uses.
    final notifier = container.read(settingsProvider.notifier);

    await notifier.setNotificationsEnabled(true);
    expect(notifier.state.notificationsEnabled, true);

    await notifier.setAlertApprovals(false);
    expect(notifier.state.alertApprovals, false);

    await notifier.setAlertTurnFinished(false);
    expect(notifier.state.alertTurnFinished, false);

    await notifier.setAlertBackgroundWaiting(false);
    expect(notifier.state.alertBackgroundWaiting, false);

    await notifier.setAlertCronFailures(false);
    expect(notifier.state.alertCronFailures, false);

    await notifier.setAlertWhileForeground(true);
    expect(notifier.state.alertWhileForeground, true);

    expect(prefs.getBool('notificationsEnabled'), true);
    expect(prefs.getBool('alertApprovals'), false);
    expect(prefs.getBool('alertTurnFinished'), false);
    expect(prefs.getBool('alertBackgroundWaiting'), false);
    expect(prefs.getBool('alertCronFailures'), false);
    expect(prefs.getBool('alertWhileForeground'), true);
  });

  test('settingsProviderWith builds an isolated store over the given prefs',
      () async {
    // The factory seam itself: hold the returned provider once (a second call
    // would be a different provider) and confirm it loads and persists through
    // the supplied store rather than the app-wide singleton.
    SharedPreferences.setMockInitialValues(
        <String, Object>{'theme': ThemePref.light.index});
    final prefs = await SharedPreferences.getInstance();
    final provider = settingsProviderWith(prefs: prefs);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading the provider constructs the notifier, which calls `_load()` and
    // awaits the supplied prefs instance; give that microtask a turn.
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).theme, ThemePref.light);

    await container.read(provider.notifier).setSkin('ember');
    expect(prefs.getString('skin'), 'ember');
  });

  testWidgets('on-device row follows the v1 platform gate (THE-110)',
      (tester) async {
    _seedInMemoryPrefs();
    final prefs = await SharedPreferences.getInstance();

    Future<void> pumpAdvanced() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _settingsOverrides(prefs: prefs),
          child: MaterialApp(theme: PiTheme.dark, home: const SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
    }

    try {
      // iOS: the state is shown, with no button that cannot work.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pumpAdvanced();
      expect(find.text('Open on-device chat'), findsNothing);
      expect(find.textContaining('Android-only in v1'), findsOneWidget);

      // Android: unchanged behaviour.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pumpAdvanced();
      expect(find.text('Open on-device chat'), findsOneWidget);
      expect(find.textContaining('Android-only in v1'), findsNothing);
    } finally {
      // Must be restored inside the test body: flutter_test asserts foundation
      // debug variables are unset before tearDowns run.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
