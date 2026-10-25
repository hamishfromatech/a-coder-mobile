// Desktop skin parity: the mobile presets must resolve to the same colors the
// desktop produces from theme-presets.ts + apply-theme.ts.
library;

import 'package:acoder_mobile/design/skins.dart';
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/design/theme_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skin registry matches the desktop list', () {
    expect(piSkinList.map((s) => s.name).toList(), [
      'aurora',
      'nous',
      'midnight',
      'ember',
      'mono',
      'cyberpunk',
      'slate',
      'nord',
      'dracula',
      'gruvbox',
      'catppuccin',
      'tokyo-night',
    ]);
    expect(piSkinList.first.label, 'Aurora');
    expect(piSkinList.last.label, 'Tokyo Night');
    expect(defaultSkinName, 'aurora');
  });

  test('aurora resolves to the desktop default tokens', () {
    final dark = resolveSkinPalette('aurora', true);
    expect(dark.bg, '#0a0a0c');
    expect(dark.surface, '#0e0e11');
    expect(dark.surfaceRaised, '#16161b');
    expect(dark.surfaceOverlay, '#1c1c22');
    expect(dark.text, '#e8e9ee');
    expect(dark.accent, '#2e7fff');
    expect(dark.accentHover, '#4a95ff');
    expect(dark.user, '#7fd1a0');
    expect(dark.tool, '#a3a3ff');

    final light = resolveSkinPalette('aurora', false);
    expect(light.bg, '#f6f6f8');
    expect(light.surface, '#ffffff');
    expect(light.accent, '#0053fd');
    expect(light.text, '#1a1b22');
  });

  test('hermes skins convert through the desktop token math', () {
    final nousDark = resolveSkinPalette('nous', true);
    expect(nousDark.bg, '#0D2F86');
    expect(nousDark.text, '#FFE6CB');
    expect(nousDark.accent, '#0053FD');
    expect(nousDark.surface, '#09286F');

    final midnight = resolveSkinPalette('midnight', true);
    expect(midnight.bg, '#08081c');
    expect(midnight.accent, '#8b80e8');
    // Dark-only skins synthesise a light variant.
    final midnightLight = resolveSkinPalette('midnight', false);
    expect(midnightLight.bg, '#ffffff');

    final nordDark = resolveSkinPalette('nord', true);
    expect(nordDark.bg, '#2e3440');
    expect(nordDark.accent, '#81a1c1');

    final tokyoLight = resolveSkinPalette('tokyo-night', false);
    expect(tokyoLight.bg, '#e1e2e7');
    expect(tokyoLight.accent, '#2e5de5');
  });

  test('every skin keeps body text readable on its background', () {
    for (final meta in piSkinList) {
      for (final dark in [true, false]) {
        final p = resolveSkinPalette(meta.name, dark);
        final ratio = contrastRatio(p.text, p.bg);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${meta.name} ${dark ? 'dark' : 'light'} text/bg');
        // The desktop guarantees the *assistant* accent via ensureContrast(3);
        // the raw accent can stay decorative (e.g. neon cyberpunk on white).
        final accentRatio = contrastRatio(p.assistant, p.bg);
        expect(accentRatio, greaterThanOrEqualTo(3.0),
            reason: '${meta.name} ${dark ? 'dark' : 'light'} assistant/bg');
        for (final hex in [
          p.bg,
          p.surface,
          p.surfaceRaised,
          p.surfaceOverlay,
          p.text,
          p.textSecondary,
          p.textMuted,
          p.textFaint,
          p.accent,
          p.accentHover,
          p.user,
          p.assistant,
          p.tool,
          p.success,
          p.warning,
          p.error,
        ]) {
          expect(hexToRgb(hex), isNotNull,
              reason: '${meta.name}: invalid token $hex');
        }
      }
    }
  });

  test('unknown skin names fall back to aurora', () {
    expect(normalizeSkinName('nope'), 'aurora');
    expect(normalizeSkinName(null), 'aurora');
    expect(normalizeSkinName('dracula'), 'dracula');
    expect(isKnownSkin('tokyo-night'), isTrue);
  });

  test('applying a skin refreshes the static token set', () {
    addTearDown(PiColors.reset);
    PiColors.apply(resolveSkinPalette('dracula', true), isDark: true);
    expect(PiColors.bg, const Color(0xFF282A36));
    expect(PiColors.accent, const Color(0xFFBD93F9));

    PiColors.apply(resolveSkinPalette('dracula', false), isDark: false);
    expect(PiColors.bg, const Color(0xFFF6F5FB));
    expect(PiColors.accent, const Color(0xFF7C4DFF));
  });

  test('color math mirrors the desktop helpers', () {
    expect(mix('#ffffff', '#000000', 0.5), '#808080');
    expect(mix('#ffffff', '#0053fd', 1), '#0053fd');
    expect(contrastRatio('#ffffff', '#000000'), closeTo(21, 0.01));
    expect(readableOn('#ffffff'), '#161616');
    expect(readableOn('#000000'), '#ffffff');
    expect(contrastRatio(ensureContrast('#101010', '#000000', 3), '#000000'),
        greaterThanOrEqualTo(3));
  });
}
