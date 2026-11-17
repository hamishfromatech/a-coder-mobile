// Golden comparison policy for host-OS rasterisation drift.
//
// Baselines are owned by CI (`macos-26`, Flutter pinned `3.47.5`). On a
// different host the same widget tree can rasterise text antialiasing slightly
// differently without any layout, colour or type change. Measured on macOS
// 27.2 (26B123) against baselines from macOS 26, nine cases drifted by
// 0.053–0.084 % of pixels (142–242 px per frame):
//
//   * every differing pixel sat on a high-contrast glyph/icon edge
//     (100 % within 1 px of a > 24/255 luminance step),
//   * the diffs formed 102–151 disconnected specks per frame, largest 28 px —
//     no shifted block, no changed geometry,
//   * the per-channel delta was tiny: median 1–2, p90 ≤ 11, max 42 of 255.
//
// A genuine regression looks nothing like that. Shifting the same frames by a
// single pixel changes 1,642–4,422 pixels with a delta > 16, i.e. 10–27× the
// 0.05 % budget, in connected runs rather than specks.
//
// So the policy is two-tier rather than "raise the percentage":
//
//   1. Pixels whose largest channel delta is ≤ [aaDelta] are treated as
//      antialiasing noise and do not count towards the failure budget.
//   2. Pixels above [aaDelta] (and therefore any real geometric or colour
//      change) must stay within the long-standing 0.05 % budget.
//   3. The *total* number of differing pixels is capped too, so a broad
//      low-contrast tint cannot hide under rule 1.
//   4. Any pixel above [grossDelta] fails outright: host jitter never gets
//      close to that, so it is a real change.
//
// If a future host upgrade moves the drift beyond these bounds, re-measure and
// change the constants deliberately — do not run `--update-goldens` off the
// baseline host. See `QA.md` → *Golden baselines vs host OS*.
import 'dart:math' as math;
import 'dart:typed_data';

/// Largest per-channel delta still treated as antialiasing noise.
///
/// Measured worst case on macOS 27.2 was 42/255 on a single pixel and p90 ≤ 11;
/// 16 keeps every measured frame at 0–7 counted pixels while a 1 px layout
/// shift changes thousands of pixels well above it.
const int aaDelta = 16;

/// Per-channel delta that never comes from host jitter. Any such pixel fails.
const int grossDelta = 64;

/// Budget for pixels above [aaDelta]: the historical 0.05 % tolerance.
const double hardPixelBudget = 0.0005;

/// Budget for any differing pixel at all. Measured drift is ≤ 0.0845 %; 0.25 %
/// leaves ~3× headroom while still catching a broad low-contrast tint.
const double noisePixelBudget = 0.0025;

/// Classification of one rendered frame against its baseline.
class GoldenDiffStats {
  const GoldenDiffStats({
    required this.totalPixels,
    required this.differingPixels,
    required this.hardPixels,
    required this.grossPixels,
  });

  /// Measures two raw RGBA buffers of identical length.
  ///
  /// Throws [ArgumentError] if the buffers are not equal, RGBA-aligned.
  factory GoldenDiffStats.fromRgba(Uint8List test, Uint8List master) {
    if (test.length != master.length || test.length % 4 != 0) {
      throw ArgumentError(
        'RGBA buffers must be equal length and 4-byte aligned '
        '(test: ${test.length}, master: ${master.length}).',
      );
    }
    var differing = 0;
    var hard = 0;
    var gross = 0;
    for (var i = 0; i < test.length; i += 4) {
      final dr = (test[i] - master[i]).abs();
      final dg = (test[i + 1] - master[i + 1]).abs();
      final db = (test[i + 2] - master[i + 2]).abs();
      final da = (test[i + 3] - master[i + 3]).abs();
      final delta = math.max(math.max(dr, dg), math.max(db, da));
      if (delta == 0) continue;
      differing++;
      if (delta > aaDelta) hard++;
      if (delta >= grossDelta) gross++;
    }
    return GoldenDiffStats(
      totalPixels: test.length ~/ 4,
      differingPixels: differing,
      hardPixels: hard,
      grossPixels: gross,
    );
  }

  /// Number of compared pixels.
  final int totalPixels;

  /// Pixels where any channel differs at all.
  final int differingPixels;

  /// Pixels where the largest channel delta exceeds [aaDelta].
  final int hardPixels;

  /// Pixels where the largest channel delta reaches [grossDelta].
  final int grossPixels;

  /// Fraction of pixels that differ at all.
  double get differingFraction =>
      totalPixels == 0 ? 1.0 : differingPixels / totalPixels;

  /// Fraction of pixels that differ by more than [aaDelta].
  double get hardFraction => totalPixels == 0 ? 1.0 : hardPixels / totalPixels;

  /// Whether this diff is indistinguishable from host rasterisation noise.
  bool get isAntialiasingJitter =>
      totalPixels > 0 &&
      grossPixels == 0 &&
      hardFraction <= hardPixelBudget &&
      differingFraction <= noisePixelBudget;

  @override
  String toString() =>
      'GoldenDiffStats($differingPixels/$totalPixels differing '
      '(${(differingFraction * 100).toStringAsFixed(3)}%), '
      '$hardPixels above Δ$aaDelta, $grossPixels above Δ$grossDelta)';
}
