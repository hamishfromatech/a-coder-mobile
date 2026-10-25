// lib/design/theme.dart
library;

/// Desktop → Mobile port of design tokens (doc 09).
/// Source: desktop-app/src/index.css :root / .light blocks and
/// desktop-app/src/lib/theme-presets.ts (12 named skins).
///
/// Public surface:
/// - [PiColors] — theme-aware tokens exposed as statics. The app scope
///   ([PiColorsScope]) refreshes them whenever the skin or light/dark mode
///   changes, so existing `PiColors.x` call sites follow the skin with no
///   edits. [PiPalette.of] is the context-based accessor.
/// - [PiTheme] — MaterialApp themes; `darkFor`/`lightFor` take a skin name.

import 'package:flutter/material.dart';

import 'skins.dart';
import 'theme_color.dart';

extension HexColorParse on String {
  /// Parse `#rrggbb` (skin palettes are all hex).
  Color get toColor {
    final rgb = hexToRgb(this);
    if (rgb == null) return Colors.black;
    return Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1);
  }
}

/// Theme-aware palette instance.
class PiPalette {
  final bool isDark;
  const PiPalette({this.isDark = true});

  // ─── Background & surfaces ────────────────────────────────────
  Color get bg => PiColors.bg;
  Color get surface => PiColors.surface;
  Color get surfaceRaised => PiColors.surfaceRaised;
  Color get surfaceOverlay => PiColors.surfaceOverlay;

  // ─── Text ─────────────────────────────────────────────────────
  Color get text => PiColors.text;
  Color get textSecondary => PiColors.textSecondary;
  Color get textMuted => PiColors.textMuted;
  Color get textFaint => PiColors.textFaint;

  // ─── Accent ───────────────────────────────────────────────────
  Color get accent => PiColors.accent;
  Color get accentSoft => PiColors.accentSoft;

  // ─── Semantic ─────────────────────────────────────────────────
  Color get success => PiColors.success;
  Color get warning => PiColors.warning;
  Color get error => PiColors.error;

  // ─── Roles ────────────────────────────────────────────────────
  Color get userBubble => PiColors.userBubble;
  Color get toolIdentity => PiColors.toolIdentity;

  // ─── Borders ──────────────────────────────────────────────────
  Color get border => PiColors.border;
  Color get borderStrong => PiColors.borderStrong;

  /// Theme-aware palette for the given context.
  static PiPalette of(BuildContext context) =>
      PiPalette(isDark: Theme.of(context).brightness == Brightness.dark);
}

/// Active design tokens.
///
/// Values default to the Aurora dark palette (desktop `:root`). [PiColorsScope]
/// re-applies them for the selected skin and light/dark mode before the app
/// subtree builds, so static access stays skin-correct.
class PiColors {
  PiColors._();

  /// Theme-aware palette for the given context.
  static PiPalette of(BuildContext context) =>
      PiPalette(isDark: Theme.of(context).brightness == Brightness.dark);

  // ─── Background & surfaces ────────────────────────────────────
  static Color bg = auroraDark.bg.toColor;
  static Color surface = auroraDark.surface.toColor;
  static Color surfaceRaised = auroraDark.surfaceRaised.toColor;
  static Color surfaceOverlay = auroraDark.surfaceOverlay.toColor;

  // ─── Text ─────────────────────────────────────────────────────
  static Color text = auroraDark.text.toColor;
  static Color textSecondary = auroraDark.textSecondary.toColor;
  static Color textMuted = auroraDark.textMuted.toColor;
  static Color textFaint = auroraDark.textFaint.toColor;

  // ─── Accent (brand blue) ──────────────────────────────────────
  static Color accent = auroraDark.accent.toColor;
  static Color accentHover = auroraDark.accentHover.toColor;
  static Color accentSoft = auroraDark.accent.toColor.withValues(alpha: 0.14);

  // ─── Semantic colors ──────────────────────────────────────────
  static Color success = auroraDark.success.toColor;
  static Color warning = auroraDark.warning.toColor;
  static Color error = auroraDark.error.toColor;

  // ─── Message role colors ──────────────────────────────────────
  static Color userBubble = auroraDark.user.toColor;
  static Color toolIdentity = auroraDark.tool.toColor;

  // ─── Borders (desktop derives these from the accent via color-mix) ──
  static Color border = auroraDark.accent.toColor.withValues(alpha: 0.14);
  static Color borderStrong = auroraDark.accent.toColor.withValues(alpha: 0.26);

  /// Apply a resolved skin palette. Derived tokens follow the desktop's
  /// `color-mix()` percentages for the active mode.
  static void apply(PiSkinPalette p, {required bool isDark}) {
    bg = p.bg.toColor;
    surface = p.surface.toColor;
    surfaceRaised = p.surfaceRaised.toColor;
    surfaceOverlay = p.surfaceOverlay.toColor;
    text = p.text.toColor;
    textSecondary = p.textSecondary.toColor;
    textMuted = p.textMuted.toColor;
    textFaint = p.textFaint.toColor;
    accent = p.accent.toColor;
    accentHover = p.accentHover.toColor;
    success = p.success.toColor;
    warning = p.warning.toColor;
    error = p.error.toColor;
    userBubble = p.user.toColor;
    toolIdentity = p.tool.toColor;
    accentSoft = p.accent.toColor.withValues(alpha: isDark ? 0.14 : 0.08);
    border = p.accent.toColor.withValues(alpha: isDark ? 0.14 : 0.16);
    borderStrong = p.accent.toColor.withValues(alpha: isDark ? 0.26 : 0.28);
  }

  /// Restore the Aurora dark defaults (test isolation).
  static void reset() => apply(auroraDark, isDark: true);
}

/// Active font stack (desktop `DesktopTheme.typography`, bundled on mobile).
class PiFonts {
  PiFonts._();
  static String mono = 'JetBrains Mono';
  static String? sans;

  static void apply(String skin) {
    final fonts = skinFonts(skin);
    mono = fonts.mono;
    sans = fonts.sans;
  }

  static void reset() => apply(defaultSkinName);
}

/// Applies the selected skin to [PiColors] for the ambient brightness, then
/// builds its child. Mounted by `MaterialApp.builder` so dialogs, sheets and
/// the navigator all see the same tokens.
class PiColorsScope extends StatelessWidget {
  final String skin;
  final Widget child;

  const PiColorsScope({super.key, required this.skin, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    PiColors.apply(resolveSkinPalette(skin, isDark), isDark: isDark);
    PiFonts.apply(skin);
    return child;
  }
}

/// App-wide theme — dark by default (desktop parity).
class PiTheme {
  static ThemeData get dark => darkFor(defaultSkinName);
  static ThemeData get light => lightFor(defaultSkinName);

  static ThemeData darkFor(String skin) => _theme(true, skin);
  static ThemeData lightFor(String skin) => _theme(false, skin);

  static ThemeData _theme(bool isDark, String skin) {
    final p = resolveSkinPalette(skin, isDark);
    final fonts = skinFonts(skin);
    final baseText =
        Typography.material2021(platform: TargetPlatform.iOS).black;
    final bg = p.bg.toColor;
    final surface = p.surface.toColor;
    final raised = p.surfaceRaised.toColor;
    final text = p.text.toColor;
    final muted = p.textMuted.toColor;
    final accent = p.accent.toColor;
    final borderColor = accent.withValues(alpha: isDark ? 0.14 : 0.16);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      // ─── Color scheme ─────────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: bg,
        onSurface: text,
        primary: accent,
        secondary: p.tool.toColor,
      ),
      // ─── Typography — system sans + JetBrains Mono for code ──
      // Desktop type scale: 13 px conversation body, 11 px captions,
      // 15 px panel titles, 10 px mono micro-labels.
      textTheme: baseText.copyWith(
        bodyLarge: TextStyle(fontSize: 13, height: 1.5, color: text),
        bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: text),
        bodySmall: TextStyle(fontSize: 11, height: 1.4, color: muted),
        titleLarge:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text),
        titleMedium:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text),
        titleSmall:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text),
        labelLarge:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: text),
        labelMedium:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          fontFamily: fonts.mono,
          color: muted,
        ),
      ),
      // ─── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: bg,
      // ─── Cards / containers ───────────────────────────────
      cardTheme: CardThemeData(
        color: raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      // ─── Input decoration (composer, text fields) ────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      // ─── App bar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      // ─── Bottom sheet / modal ─────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceOverlay.toColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      // ─── Chips ────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        labelStyle: TextStyle(
            fontSize: 10, fontFamily: fonts.mono, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // ─── Buttons ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(44, 44), // min touch target
        ),
      ),
      // ─── Lists (desktop flat rows: dense, no card chrome) ──
      listTileTheme: ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        titleTextStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: text),
        subtitleTextStyle: TextStyle(fontSize: 11, height: 1.4, color: muted),
        iconColor: muted,
      ),
      // ─── Divider ──────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
