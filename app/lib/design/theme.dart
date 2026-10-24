// lib/design/theme.dart
library;
/// Desktop → Mobile port of design tokens (doc 09).
/// Source: desktop-app/src/index.css :root / .light blocks.
///
/// Two public types:
/// - [PiColors] — static-only dark palette (desktop parity). Use for code
///   blocks/tool cards which stay dark in both themes (like the desktop).
/// - [PiPalette] — theme-aware instance palette; get it via [PiColors.of].
import 'package:flutter/material.dart';
extension RgbColorParse on String {
  /// Parse "rgb(r, g, b)" or "rgb(r g b)" (space-separated) to a Color.
  static Color parse(String raw) {
    final match = RegExp(r'rgb\((\d+)[, ]\s*(\d+)[, ]\s*(\d+)\)').firstMatch(raw);
    if (match == null) return Colors.black;
    return Color.fromRGBO(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      1,
    );
  }
}
/// Theme-aware palette instance.
class PiPalette {
  final bool isDark;
  const PiPalette({this.isDark = true});
  // ─── Background & surfaces ────────────────────────────────────
  Color get bg => isDark ? PiColors.bg : PiColors._lightBg;
  Color get surface => isDark ? PiColors.surface : const Color(0xFFFFFFFF);
  Color get surfaceRaised => isDark ? PiColors.surfaceRaised : const Color(0xFFEFEFF1);
  Color get surfaceOverlay => isDark ? PiColors.surfaceOverlay : const Color(0xFFE8E8EA);
  // ─── Text ─────────────────────────────────────────────────────
  Color get text => isDark ? PiColors.text : const Color(0xFF0F0F14);
  Color get textSecondary => isDark ? PiColors.textSecondary : const Color(0xFF5A5A64);
  Color get textMuted => isDark ? PiColors.textMuted : const Color(0xFF82828C);
  Color get textFaint => isDark ? PiColors.textFaint : const Color(0xFFAAAAB4);
  // ─── Accent ───────────────────────────────────────────────────
  Color get accent => PiColors.accent;
  Color get accentSoft => PiColors.accent.withValues(alpha: isDark ? 0.14 : 0.08);
  // ─── Semantic ─────────────────────────────────────────────────
  Color get success => PiColors.success;
  Color get warning => PiColors.warning;
  Color get error => PiColors.error;
  // ─── Roles ────────────────────────────────────────────────────
  Color get userBubble => PiColors.userBubble;
  Color get toolIdentity => PiColors.toolIdentity;
  // ─── Borders ──────────────────────────────────────────────────
  Color get border => PiColors.accent.withValues(alpha: isDark ? 0.14 : 0.16);
  Color get borderStrong => PiColors.accent.withValues(alpha: isDark ? 0.26 : 0.28);
}
/// Static dark palette — desktop `:root` defaults (doc 09).
class PiColors {
  PiColors._();
  /// Theme-aware palette for the given context.
  static PiPalette of(BuildContext context) =>
      PiPalette(isDark: Theme.of(context).brightness == Brightness.dark);
  // ─── Background & surfaces (dark defaults) ────────────────────
  static const Color bg = Color(0xFF0A0A0C); // rgb(10, 10, 12)
  static const Color surface = Color(0xFF0E0E11); // rgb(14, 14, 17)
  static const Color surfaceRaised = Color(0xFF16161B); // rgb(22, 22, 27)
  static const Color surfaceOverlay = Color(0xFF1C1C22); // rgb(28, 28, 34)
  // ─── Text ─────────────────────────────────────────────────────
  static const Color text = Color(0xFFE8E9EE); // rgb(232, 233, 238)
  static const Color textSecondary = Color(0xFFA8ACB8); // rgb(168, 172, 184)
  static const Color textMuted = Color(0xFF6F7380); // rgb(111, 115, 128)
  static const Color textFaint = Color(0xFF484B56); // rgb(72, 75, 86)
  // ─── Light values (used by PiPalette) ─────────────────────────
  static const Color _lightBg = Color(0xFFF6F6F8); // rgb(246, 246, 248)
  // ─── Accent (brand blue) ──────────────────────────────────────
  static const Color accent = Color(0xFF2E7FFF);
  static const Color accentHover = Color(0xFF4A95FF);
  static Color get accentSoft => accent.withValues(alpha: 0.14);
  // ─── Semantic colors ──────────────────────────────────────────
  static const Color success = Color(0xFF3FB98F);
  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFF05656);
  // ─── Message role colors ──────────────────────────────────────
  static const Color userBubble = Color(0xFF7FD1A0);
  static const Color toolIdentity = Color(0xFFA3A3FF);
  // ─── Borders ──────────────────────────────────────────────────
  static Color get border => accent.withValues(alpha: 0.14);
  static Color get borderStrong => accent.withValues(alpha: 0.26);
}
/// App-wide theme — dark by default (desktop parity).
class PiTheme {
  static ThemeData get dark => _theme(true);
  static ThemeData get light => _theme(false);
  static ThemeData _theme(bool isDark) {
    final c = PiPalette(isDark: isDark);
    final baseText = Typography.material2021(platform: TargetPlatform.iOS)
        .black; // TextTheme
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      // ─── Color scheme ─────────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: PiColors.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: c.bg,
        onSurface: c.text,
        primary: PiColors.accent,
        secondary: c.toolIdentity,
      ),
      // ─── Typography — system sans + JetBrains Mono for code ──
      // Desktop type scale: 13 px conversation body, 11 px captions,
      // 15 px panel titles, 10 px mono micro-labels.
      textTheme: baseText.copyWith(
        bodyLarge: const TextStyle(fontSize: 13, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 13, height: 1.5),
        bodySmall: const TextStyle(fontSize: 11, height: 1.4),
        titleLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelMedium: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        labelSmall: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          fontFamily: 'JetBrains Mono',
        ),
      ),
      // ─── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: c.bg,
      // ─── Cards / containers ───────────────────────────────
      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      // ─── Input decoration (composer, text fields) ────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PiColors.accent, width: 1.5),
        ),
      ),
      // ─── App bar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      // ─── Bottom sheet / modal ─────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceOverlay,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      // ─── Chips ────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: c.accentSoft,
        labelStyle: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // ─── Buttons ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PiColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(44, 44), // min touch target
        ),
      ),
      // ─── Lists (desktop flat rows: dense, no card chrome) ──
      listTileTheme: ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        titleTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.text,
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: PiColors.textMuted,
        ),
        iconColor: c.textMuted,
      ),
      // ─── Divider ──────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 0,
      ),
    );
  }
}