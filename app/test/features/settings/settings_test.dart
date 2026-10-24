import 'package:acoder_mobile/features/settings/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setTheme(ThemePref.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme'), ThemePref.light.index);
    expect(container.read(settingsProvider).theme, ThemePref.light);
  });

  test('text size persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setChatTextSize(16);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('chatTextSize'), 16.0);
    expect(container.read(settingsProvider).chatTextSize, 16.0);
  });
}
