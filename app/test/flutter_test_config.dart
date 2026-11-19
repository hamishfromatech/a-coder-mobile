// Global test configuration.
//
// Golden images are rasterised by the host OS. Baselines are owned by CI
// (`.github/workflows/mobile.yml`: macos-26, Flutter pinned 3.47.5) and must
// not be regenerated on another host — `--update-goldens` on macOS 27 would
// move the mismatch into CI.
//
// A matching app on a different host still rasterises text antialiasing
// slightly differently. That is why this comparator has two tiers: a small
// per-channel delta counts as noise (bounded, so it cannot hide a real
// change), while anything above it falls back to the historical 0.05 %
// pixel budget. `test/support/golden_comparator.dart` holds the thresholds,
// the macOS 27.2 measurements behind them, and the calibration test.
//
// Do not raise a threshold without re-measuring the diffs a failing golden
// reports. See `QA.md` → *Golden baselines vs host OS*.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show FlutterError, debugPrint, listEquals;
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_comparator.dart' as policy;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    // LocalFileComparator does not expose its testFile, only the derived
    // basedir. Reconstructing a file URI inside that directory preserves the
    // lookup the framework already configured for this test file.
    final probe = Uri.parse('${current.basedir}golden_probe_test.dart');
    goldenFileComparator = _TolerantGoldenFileComparator(probe);
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final masterBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      masterBytes,
    );

    if (result.passed) {
      result.dispose();
      return true;
    }

    // A failing comparison can still be host rasteriser noise: many glyph-edge
    // pixels that differ only slightly. Measure before failing.
    final stats = await _measure(imageBytes, masterBytes);
    if (stats != null && stats.isAntialiasingJitter) {
      debugPrint('Golden "$golden": ${stats.toString()} — accepted as '
          'host antialiasing jitter (baselines are owned by macos-26 CI).');
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }

  /// Returns pixel statistics, or null when the frames cannot be compared.
  Future<policy.GoldenDiffStats?> _measure(
    Uint8List testBytes,
    Uint8List masterBytes,
  ) async {
    if (listEquals(testBytes, masterBytes)) return null;
    final test = await _rgba(testBytes);
    final master = await _rgba(masterBytes);
    if (test == null || master == null) return null;
    if (test.length != master.length) return null;
    return policy.GoldenDiffStats.fromRgba(test, master);
  }

  static Future<Uint8List?> _rgba(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
