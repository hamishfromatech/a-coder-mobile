// Desktop skin presets, ported verbatim from
// desktop-app/src/lib/theme-presets.ts + apply-theme.ts.
//
// `aurora` is the default and is authored directly as a full token pair.
// The other 11 skins ship in the Hermes `DesktopTheme` shape and are converted
// into the richer token set with the same math the desktop uses, so a skin
// resolves to identical colors on both clients.
library;

import 'theme_color.dart';

/// Fully resolved token set (desktop `PiPalette`).
class PiSkinPalette {
  final String bg;
  final String surface;
  final String surfaceRaised;
  final String surfaceOverlay;
  final String text;
  final String textSecondary;
  final String textMuted;
  final String textFaint;
  final String accent;
  final String accentHover;
  final String user;
  final String assistant;
  final String tool;
  final String success;
  final String warning;
  final String error;

  const PiSkinPalette({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentHover,
    required this.user,
    required this.assistant,
    required this.tool,
    required this.success,
    required this.warning,
    required this.error,
  });
}

/// Skin metadata shown in the picker (desktop `SkinMeta`).
class PiSkinMeta {
  final String name;
  final String label;
  final String description;
  const PiSkinMeta(this.name, this.label, this.description);
}

// ─── Aurora — the a-coder default ───────────────────────────────────────────

const auroraDark = PiSkinPalette(
  bg: '#0a0a0c',
  surface: '#0e0e11',
  surfaceRaised: '#16161b',
  surfaceOverlay: '#1c1c22',
  text: '#e8e9ee',
  textSecondary: '#a8acb8',
  textMuted: '#6f7380',
  textFaint: '#484b56',
  accent: '#2e7fff',
  accentHover: '#4a95ff',
  user: '#7fd1a0',
  assistant: '#2e7fff',
  tool: '#a3a3ff',
  success: '#3fb98f',
  warning: '#eab308',
  error: '#f05656',
);

const auroraLight = PiSkinPalette(
  bg: '#f6f6f8',
  surface: '#ffffff',
  surfaceRaised: '#f1f1f4',
  surfaceOverlay: '#ffffff',
  text: '#1a1b22',
  textSecondary: '#44474f',
  textMuted: '#71747c',
  textFaint: '#a8aab3',
  accent: '#0053fd',
  accentHover: '#0040cc',
  user: '#1a8e69',
  assistant: '#0053fd',
  tool: '#6366f1',
  success: '#16a36e',
  warning: '#ca8a04',
  error: '#dc2626',
);

// ─── Hermes theme model (only the fields the token conversion consumes) ────

class _HermesColors {
  final String background;
  final String foreground;
  final String card;
  final String mutedForeground;
  final String popover;
  final String primary;
  final String ring;
  final String? midground;
  final String destructive;
  final String? sidebarBackground;

  const _HermesColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.mutedForeground,
    required this.popover,
    required this.primary,
    required this.ring,
    this.midground,
    required this.destructive,
    this.sidebarBackground,
  });
}

class _HermesSkin {
  final String name;
  final String label;
  final String description;
  final _HermesColors colors;
  final _HermesColors? darkColors;
  const _HermesSkin(
    this.name,
    this.label,
    this.description,
    this.colors, {
    this.darkColors,
  });
}

// ─── Hermes skins (ported verbatim) ─────────────────────────────────────────

const _nousBlue = '#0053FD';
const _psycheWarm = '#FFE6CB';

final _skins = <_HermesSkin>[
  const _HermesSkin(
    'nous',
    'Nous',
    'Glass neutrals with Nous blue accents',
    _HermesColors(
      background: '#F8FAFF',
      foreground: '#17171A',
      card: '#FFFFFF',
      mutedForeground: '#666678',
      popover: '#FFFFFF',
      primary: _nousBlue,
      ring: _nousBlue,
      midground: _nousBlue,
      destructive: '#C72E4D',
      sidebarBackground: '#F3F7FF',
    ),
    darkColors: _HermesColors(
      background: '#0D2F86',
      foreground: _psycheWarm,
      card: '#12378F',
      mutedForeground: '#B5C7F3',
      popover: '#123A96',
      primary: _psycheWarm,
      ring: _psycheWarm,
      midground: _nousBlue,
      destructive: '#C0473A',
      sidebarBackground: '#09286F',
    ),
  ),
  const _HermesSkin(
    'midnight',
    'Midnight',
    'Deep blue-violet with cool accents',
    _HermesColors(
      background: '#08081c',
      foreground: '#ddd6ff',
      card: '#0d0d28',
      mutedForeground: '#7c7ab0',
      popover: '#0f0f2e',
      primary: '#ddd6ff',
      ring: '#8b80e8',
      midground: '#8b80e8',
      destructive: '#b03060',
      sidebarBackground: '#06061a',
    ),
  ),
  const _HermesSkin(
    'ember',
    'Ember',
    'Warm crimson and bronze — forge vibes',
    _HermesColors(
      background: '#160800',
      foreground: '#ffd8b0',
      card: '#1e0e04',
      mutedForeground: '#aa7a56',
      popover: '#221008',
      primary: '#ffd8b0',
      ring: '#d97316',
      midground: '#d97316',
      destructive: '#c43010',
      sidebarBackground: '#100600',
    ),
  ),
  const _HermesSkin(
    'mono',
    'Mono',
    'Clean grayscale — minimal and focused',
    _HermesColors(
      background: '#0e0e0e',
      foreground: '#eaeaea',
      card: '#141414',
      mutedForeground: '#808080',
      popover: '#181818',
      primary: '#eaeaea',
      ring: '#9a9a9a',
      midground: '#9a9a9a',
      destructive: '#a84040',
      sidebarBackground: '#0a0a0a',
    ),
  ),
  const _HermesSkin(
    'cyberpunk',
    'Cyberpunk',
    'Neon green on black — matrix terminal',
    _HermesColors(
      background: '#000a00',
      foreground: '#00ff41',
      card: '#001200',
      mutedForeground: '#1a8a30',
      popover: '#001000',
      primary: '#00ff41',
      ring: '#00ff41',
      midground: '#00ff41',
      destructive: '#ff003c',
      sidebarBackground: '#000600',
    ),
  ),
  const _HermesSkin(
    'slate',
    'Slate',
    'Cool slate blue — focused developer theme',
    _HermesColors(
      background: '#0d1117',
      foreground: '#c9d1d9',
      card: '#161b22',
      mutedForeground: '#8b949e',
      popover: '#1c2128',
      primary: '#c9d1d9',
      ring: '#58a6ff',
      midground: '#58a6ff',
      destructive: '#cf4848',
      sidebarBackground: '#090d13',
    ),
  ),
  const _HermesSkin(
    'nord',
    'Nord',
    'Cool polar-night blues with frost accents',
    _HermesColors(
      background: '#eceff4',
      foreground: '#2e3440',
      card: '#f2f4f8',
      mutedForeground: '#5c6a7d',
      popover: '#ffffff',
      primary: '#5e81ac',
      ring: '#5e81ac',
      midground: '#5e81ac',
      destructive: '#bf616a',
      sidebarBackground: '#e6eaf2',
    ),
    darkColors: _HermesColors(
      background: '#2e3440',
      foreground: '#d8dee9',
      card: '#353c4a',
      mutedForeground: '#8fa1b3',
      popover: '#3b4252',
      primary: '#88c0d0',
      ring: '#88c0d0',
      midground: '#81a1c1',
      destructive: '#bf616a',
      sidebarBackground: '#272c36',
    ),
  ),
  const _HermesSkin(
    'dracula',
    'Dracula',
    'Classic purple prose — violet, pink, and cyan on midnight',
    _HermesColors(
      background: '#f6f5fb',
      foreground: '#3c3a52',
      card: '#fbfaff',
      mutedForeground: '#6f6a90',
      popover: '#ffffff',
      primary: '#7c4dff',
      ring: '#a269ff',
      midground: '#7c4dff',
      destructive: '#d33a6c',
      sidebarBackground: '#efedf8',
    ),
    darkColors: _HermesColors(
      background: '#282a36',
      foreground: '#f8f8f2',
      card: '#2f313f',
      mutedForeground: '#9aa0bd',
      popover: '#343746',
      primary: '#bd93f9',
      ring: '#bd93f9',
      midground: '#bd93f9',
      destructive: '#ff5555',
      sidebarBackground: '#22242e',
    ),
  ),
  const _HermesSkin(
    'gruvbox',
    'Gruvbox',
    'Warm retro groove — sand paper, forest greens, burnt orange',
    _HermesColors(
      background: '#fbf1c7',
      foreground: '#3c3836',
      card: '#f9ecc0',
      mutedForeground: '#7c6f64',
      popover: '#fdf6e0',
      primary: '#b57614',
      ring: '#d65d0e',
      midground: '#d65d0e',
      destructive: '#9d0006',
      sidebarBackground: '#f4e9bc',
    ),
    darkColors: _HermesColors(
      background: '#282828',
      foreground: '#ebdbb2',
      card: '#2e2c29',
      mutedForeground: '#bdae93',
      popover: '#32302c',
      primary: '#fe8019',
      ring: '#fe8019',
      midground: '#fe8019',
      destructive: '#fb4934',
      sidebarBackground: '#232323',
    ),
  ),
  const _HermesSkin(
    'catppuccin',
    'Catppuccin',
    'Soothing pastel — Latte by day, Mocha by night',
    _HermesColors(
      background: '#eff1f5',
      foreground: '#4c4f69',
      card: '#f5f6fa',
      mutedForeground: '#6c6f85',
      popover: '#ffffff',
      primary: '#8839ef',
      ring: '#8839ef',
      midground: '#8839ef',
      destructive: '#d20f39',
      sidebarBackground: '#e9ebf2',
    ),
    darkColors: _HermesColors(
      background: '#1e1e2e',
      foreground: '#cdd6f4',
      card: '#26263a',
      mutedForeground: '#a6adc8',
      popover: '#313244',
      primary: '#cba6f7',
      ring: '#cba6f7',
      midground: '#cba6f7',
      destructive: '#f38ba8',
      sidebarBackground: '#181825',
    ),
  ),
  const _HermesSkin(
    'tokyo-night',
    'Tokyo Night',
    'City-lights indigo — neon blues and purples over a dark skyline',
    _HermesColors(
      background: '#e1e2e7',
      foreground: '#3760bf',
      card: '#e9ebf2',
      mutedForeground: '#6172b0',
      popover: '#f3f4fa',
      primary: '#2e5de5',
      ring: '#2e5de5',
      midground: '#2e5de5',
      destructive: '#c64343',
      sidebarBackground: '#d9dbe4',
    ),
    darkColors: _HermesColors(
      background: '#1a1b26',
      foreground: '#c0caf5',
      card: '#20212f',
      mutedForeground: '#9aa5ce',
      popover: '#262939',
      primary: '#7aa2f7',
      ring: '#7aa2f7',
      midground: '#7aa2f7',
      destructive: '#f7768e',
      sidebarBackground: '#15161e',
    ),
  ),
];

// ─── Conversion (desktop colorsToPiPalette + synthLightColors) ─────────────

_HermesColors _synthLightColors(_HermesSkin seed) {
  final accent = seed.colors.ring;
  return _HermesColors(
    background: '#ffffff',
    foreground: '#161616',
    card: '#ffffff',
    mutedForeground: mix('#6b6b70', accent, 0.16),
    popover: '#ffffff',
    primary: accent,
    ring: accent,
    midground: seed.colors.midground ?? accent,
    destructive: '#b94a3a',
    sidebarBackground: mix('#fafafa', accent, 0.05),
  );
}

_HermesColors _baseColors(_HermesSkin skin, bool dark) {
  if (dark) return skin.darkColors ?? skin.colors;
  return skin.darkColors != null ? skin.colors : _synthLightColors(skin);
}

PiSkinPalette _colorsToPalette(_HermesColors colors) {
  final accent = colors.midground ?? colors.ring;
  final bg = colors.background;
  final fg = colors.foreground;
  return PiSkinPalette(
    bg: bg,
    surface: colors.sidebarBackground ?? colors.card,
    surfaceRaised: colors.card,
    surfaceOverlay: colors.popover,
    text: fg,
    textSecondary: mix(fg, colors.mutedForeground, 0.5),
    textMuted: colors.mutedForeground,
    textFaint: mix(colors.mutedForeground, bg, 0.45),
    accent: accent,
    accentHover: mix(accent, fg, 0.14),
    user: ensureContrast('#34d399', bg, 3),
    assistant: ensureContrast(accent, bg, 3),
    tool: ensureContrast('#a3a3ff', bg, 3),
    success: ensureContrast('#22c55e', bg, 3),
    warning: ensureContrast('#eab308', bg, 3),
    error: ensureContrast(colors.destructive, bg, 3),
  );
}

// ─── Public registry ──────────────────────────────────────────────────────

const defaultSkinName = 'aurora';

/// Desktop `SKIN_LIST` order and copy.
final List<PiSkinMeta> piSkinList = [
  const PiSkinMeta(
    'aurora',
    'Aurora',
    'Neutral glass with Nous-blue accent — the a-coder default',
  ),
  ..._skins.map((s) => PiSkinMeta(s.name, s.label, s.description)),
];

bool isKnownSkin(String name) =>
    name == defaultSkinName || _skins.any((s) => s.name == name);

String normalizeSkinName(String? name) =>
    name != null && isKnownSkin(name) ? name : defaultSkinName;

// ─── Typography (desktop `DesktopTheme.typography`) ────────────────────────
//
// Fonts are bundled (pubspec `fonts:`) because a phone cannot inject the
// desktop's Google Fonts stylesheet at runtime. Cyberpunk's Courier New is not
// redistributable, so Courier Prime is the bundled equivalent.

class PiSkinFonts {
  /// Null means "use the platform default sans".
  final String? sans;
  final String mono;
  const PiSkinFonts({required this.sans, required this.mono});
}

const _systemSans = null;
const _jetBrains = 'JetBrains Mono';
const _courierPrime = 'Courier Prime';
const _plexMono = 'IBM Plex Mono';

PiSkinFonts skinFonts(String skinName) => switch (skinName) {
      'nous' => const PiSkinFonts(sans: _systemSans, mono: _courierPrime),
      'ember' => const PiSkinFonts(sans: _systemSans, mono: _plexMono),
      'cyberpunk' =>
        const PiSkinFonts(sans: _courierPrime, mono: _courierPrime),
      _ => const PiSkinFonts(sans: _systemSans, mono: _jetBrains),
    };

/// Resolve a skin + resolved light/dark mode into the full token set.
PiSkinPalette resolveSkinPalette(String skinName, bool dark) {
  if (skinName == defaultSkinName) return dark ? auroraDark : auroraLight;
  for (final skin in _skins) {
    if (skin.name == skinName) {
      return _colorsToPalette(_baseColors(skin, dark));
    }
  }
  return dark ? auroraDark : auroraLight;
}
