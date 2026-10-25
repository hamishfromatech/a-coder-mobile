// lib/features/settings/providers/settings_providers.dart
library;

/// Persisted appearance + interaction settings (desktop SettingsPanel parity):
/// theme mode (dark-first, doc 09), named skin, chat text size, haptics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePref { system, dark, light }

class AppSettings {
  final ThemePref theme;
  final String skin; // desktop skin name (design/skins.dart)
  final double chatTextSize; // 13–17sp (doc 06 §5)
  final bool haptics;
  const AppSettings({
    this.theme = ThemePref.dark,
    this.skin = 'aurora',
    this.chatTextSize = 14.5,
    this.haptics = true,
  });
  ThemeMode get themeMode => switch (theme) {
        ThemePref.system => ThemeMode.system,
        ThemePref.dark => ThemeMode.dark,
        ThemePref.light => ThemeMode.light,
      };
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      theme: ThemePref.values.asMap()[prefs.getInt('theme') ?? 1] ??
          ThemePref.dark,
      skin: prefs.getString('skin') ?? 'aurora',
      chatTextSize: prefs.getDouble('chatTextSize') ?? 14.5,
      haptics: prefs.getBool('haptics') ?? true,
    );
  }

  Future<void> setTheme(ThemePref theme) async {
    state = AppSettings(
      theme: theme,
      skin: state.skin,
      chatTextSize: state.chatTextSize,
      haptics: state.haptics,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', theme.index);
  }

  Future<void> setSkin(String skin) async {
    state = AppSettings(
      theme: state.theme,
      skin: skin,
      chatTextSize: state.chatTextSize,
      haptics: state.haptics,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skin', skin);
  }

  Future<void> setChatTextSize(double size) async {
    state = AppSettings(
      theme: state.theme,
      skin: state.skin,
      chatTextSize: size,
      haptics: state.haptics,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chatTextSize', size);
  }

  Future<void> setHaptics(bool enabled) async {
    state = AppSettings(
      theme: state.theme,
      skin: state.skin,
      chatTextSize: state.chatTextSize,
      haptics: enabled,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics', enabled);
  }
}
