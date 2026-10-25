// Color math shared by the desktop skin presets and their mobile port.
//
// Mirrors desktop-app/src/lib/theme-color.ts numerically so a skin resolves to
// the same colors on both clients. Everything works on 6-digit `#rrggbb`.
library;

import 'dart:math' as math;

class Rgb {
  final int r;
  final int g;
  final int b;
  const Rgb(this.r, this.g, this.b);
}

Rgb? hexToRgb(String hex) {
  final clean = hex.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) return null;
  return Rgb(
    int.parse(clean.substring(0, 2), radix: 16),
    int.parse(clean.substring(2, 4), radix: 16),
    int.parse(clean.substring(4, 6), radix: 16),
  );
}

String rgbToHex(Rgb c) => '#${[
      c.r,
      c.g,
      c.b,
    ].map((n) => n.clamp(0, 255).round().toRadixString(16).padLeft(2, '0')).join()}';

/// Linear interpolation from [a] toward [b] by [amount] (0..1).
String mix(String a, String b, double amount) {
  final ar = hexToRgb(a);
  final br = hexToRgb(b);
  if (ar == null || br == null) return a;
  return rgbToHex(Rgb(
    (ar.r + (br.r - ar.r) * amount).round(),
    (ar.g + (br.g - ar.g) * amount).round(),
    (ar.b + (br.b - ar.b) * amount).round(),
  ));
}

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance (gamma-corrected), 0..1.
double relativeLuminance(String hex) {
  final rgb = hexToRgb(hex);
  if (rgb == null) return 0;
  final r = _linearize(rgb.r / 255);
  final g = _linearize(rgb.g / 255);
  final b = _linearize(rgb.b / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG contrast ratio (1..21) between two hex colors.
double contrastRatio(String a, String b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return la >= lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Readable foreground (#161616 or #ffffff) for a background hex.
String readableOn(String hex) =>
    relativeLuminance(hex) > 0.58 ? '#161616' : '#ffffff';

/// Guarantee [color] reads against [bg] by mixing toward white (dark bg) or
/// black (light bg) in 20% steps until [min] contrast is met.
String ensureContrast(String color, String bg, double min) {
  if (contrastRatio(color, bg) >= min) return color;
  final towards = relativeLuminance(bg) < 0.5 ? '#ffffff' : '#000000';
  var best = color;
  for (var amount = 0.2; amount <= 1.0001; amount += 0.2) {
    best = mix(color, towards, amount > 1 ? 1 : amount);
    if (contrastRatio(best, bg) >= min) return best;
  }
  return best;
}
