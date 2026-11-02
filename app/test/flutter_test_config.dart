// Global test configuration.
//
// Golden images are rasterised by the host OS. The baselines are generated on
// macOS 26 (see .github/workflows/mobile.yml, pinned to macos-26). Even on a
// matching runner image, a macOS point update or an x64/arm64 difference can
// shift antialiasing by a handful of pixels. A strict pixel-for-pixel
// comparison turns that into a red build unrelated to any code change.
//
// Allow a maximum of 0.05% differing pixels (≈165 px on a 390x844 frame).
// Real regressions — layout, colour, type, spacing — exceed that by orders of
// magnitude; known-good jitter is 1-7 px (≈0.002%). This is deliberately not
// a "loosen until green" knob: do not raise it without measuring the diff
// reported by a failing golden.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// Fraction of differing pixels tolerated between a golden and a render.
const double _kGoldenPixelTolerance = 0.0005;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    // LocalFileComparator does not expose its testFile, only the derived
    // basedir. Reconstructing a file URI inside that directory preserves the
    // lookup the framework already configured for this test file.
    final probe = Uri.parse('${current.basedir}golden_probe_test.dart');
    goldenFileComparator = _TolerantGoldenFileComparator(
      probe,
      pixelTolerance: _kGoldenPixelTolerance,
    );
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required this.pixelTolerance,
  });

  /// Maximum fraction of differing pixels that still counts as a match.
  final double pixelTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= pixelTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
