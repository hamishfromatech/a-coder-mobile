// lib/features/settings/providers/settings_providers.dart
library;

/// Persisted appearance + interaction settings (desktop SettingsPanel parity):
/// theme mode (dark-first, doc 09), named skin, chat text size, chat backdrop,
/// haptics, and local alert preferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePref { system, dark, light }

class AppSettings {
  final ThemePref theme;
  final String skin; // desktop skin name (design/skins.dart)
  final double chatTextSize; // 13–17sp (doc 06 §5)
  final bool haptics;

  /// Desktop `chatBackdrop`: the faint image behind the transcript.
  final bool chatBackdrop;

  // ─── Alerts (local notifications) ───────────────────────────────────
  final bool notificationsEnabled;
  final bool alertApprovals;
  final bool alertTurnFinished;
  final bool alertBackgroundWaiting;
  final bool alertCronFailures;
  final bool alertWhileForeground;

  const AppSettings({
    this.theme = ThemePref.dark,
    this.skin = 'aurora',
    this.chatTextSize = 14.5,
    this.haptics = true,
    this.chatBackdrop = true,
    this.notificationsEnabled = false,
    this.alertApprovals = true,
    this.alertTurnFinished = true,
    this.alertBackgroundWaiting = true,
    this.alertCronFailures = true,
    this.alertWhileForeground = false,
  });

  ThemeMode get themeMode => switch (theme) {
        ThemePref.system => ThemeMode.system,
        ThemePref.dark => ThemeMode.dark,
        ThemePref.light => ThemeMode.light,
      };

  AppSettings copyWith({
    ThemePref? theme,
    String? skin,
    double? chatTextSize,
    bool? haptics,
    bool? chatBackdrop,
    bool? notificationsEnabled,
    bool? alertApprovals,
    bool? alertTurnFinished,
    bool? alertBackgroundWaiting,
    bool? alertCronFailures,
    bool? alertWhileForeground,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        skin: skin ?? this.skin,
        chatTextSize: chatTextSize ?? this.chatTextSize,
        haptics: haptics ?? this.haptics,
        chatBackdrop: chatBackdrop ?? this.chatBackdrop,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        alertApprovals: alertApprovals ?? this.alertApprovals,
        alertTurnFinished: alertTurnFinished ?? this.alertTurnFinished,
        alertBackgroundWaiting:
            alertBackgroundWaiting ?? this.alertBackgroundWaiting,
        alertCronFailures: alertCronFailures ?? this.alertCronFailures,
        alertWhileForeground: alertWhileForeground ?? this.alertWhileForeground,
      );
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Injectable settings-store seam.
///
/// Builds a settings provider backed by an explicit `SharedPreferences` instead
/// of the app-wide singleton. Production keeps using the default `settingsProvider`
/// (which still resolves to `SharedPreferences.getInstance()`), so behaviour is
/// unchanged — this only lets widgets/tests drive the store with isolated,
/// in-memory prefs.
///
/// Each call returns a **new** provider, so hold the result: reading a fresh
/// `settingsProviderWith(...)` in a test creates a second, detached notifier
/// instead of the one a `ProviderScope` override is rendering.
StateNotifierProvider<SettingsNotifier, AppSettings> settingsProviderWith(
  {SharedPreferences? prefs,
   AppSettings? initial,
  }) {
  return StateNotifierProvider<SettingsNotifier, AppSettings>((ref) =>
      SettingsNotifier(prefs: prefs, initial: initial));
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  /// Injectable preferences store. `null` resolves to the global
  /// `SharedPreferences.getInstance()` exactly as before, keeping production
  /// behaviour unchanged.
  SharedPreferences? _prefs;

  /// Values the notifier started from, used to tell a load back from a setter.
  late AppSettings _initial;

  SettingsNotifier({
    SharedPreferences? prefs,
    AppSettings? initial,
  }) : super(initial ?? const AppSettings()) {
    _prefs = prefs;
    _initial = initial ?? const AppSettings();
    _load();
  }

  Future<SharedPreferences> _prefsInstance() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _prefsInstance();
    // Only apply the persisted values when no setter has already pinned the
    // state. Running the async load here (called from the constructor) would
    // otherwise land after a setter and reset `state` back to the values read
    // at construction time.
    if (state == _initial) {
      state = AppSettings(
        theme: ThemePref.values.asMap()[prefs.getInt('theme') ?? 1] ??
            ThemePref.dark,
        skin: prefs.getString('skin') ?? 'aurora',
        chatTextSize: prefs.getDouble('chatTextSize') ?? 14.5,
        haptics: prefs.getBool('haptics') ?? true,
        chatBackdrop: prefs.getBool('chatBackdrop') ?? true,
        notificationsEnabled: prefs.getBool('notificationsEnabled') ?? false,
        alertApprovals: prefs.getBool('alertApprovals') ?? true,
        alertTurnFinished: prefs.getBool('alertTurnFinished') ?? true,
        alertBackgroundWaiting: prefs.getBool('alertBackgroundWaiting') ?? true,
        alertCronFailures: prefs.getBool('alertCronFailures') ?? true,
        alertWhileForeground: prefs.getBool('alertWhileForeground') ?? false,
      );
    }
  }

  Future<void> setTheme(ThemePref theme) async {
    state = state.copyWith(theme: theme);
    final prefs = await _prefsInstance();
    await prefs.setInt('theme', theme.index);
  }

  Future<void> setSkin(String skin) async {
    state = state.copyWith(skin: skin);
    final prefs = await _prefsInstance();
    await prefs.setString('skin', skin);
  }

  Future<void> setChatTextSize(double size) async {
    state = state.copyWith(chatTextSize: size);
    final prefs = await _prefsInstance();
    await prefs.setDouble('chatTextSize', size);
  }

  Future<void> setHaptics(bool enabled) async {
    state = state.copyWith(haptics: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('haptics', enabled);
  }

  Future<void> setChatBackdrop(bool enabled) async {
    state = state.copyWith(chatBackdrop: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('chatBackdrop', enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('notificationsEnabled', enabled);
  }

  Future<void> setAlertApprovals(bool enabled) async {
    state = state.copyWith(alertApprovals: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('alertApprovals', enabled);
  }

  Future<void> setAlertTurnFinished(bool enabled) async {
    state = state.copyWith(alertTurnFinished: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('alertTurnFinished', enabled);
  }

  Future<void> setAlertBackgroundWaiting(bool enabled) async {
    state = state.copyWith(alertBackgroundWaiting: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('alertBackgroundWaiting', enabled);
  }

  Future<void> setAlertCronFailures(bool enabled) async {
    state = state.copyWith(alertCronFailures: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('alertCronFailures', enabled);
  }

  Future<void> setAlertWhileForeground(bool enabled) async {
    state = state.copyWith(alertWhileForeground: enabled);
    final prefs = await _prefsInstance();
    await prefs.setBool('alertWhileForeground', enabled);
  }
}
