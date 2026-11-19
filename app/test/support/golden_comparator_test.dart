// Calibration for the golden comparison policy.
//
// These cases pin the numbers in `golden_comparator.dart` to behaviour: host
// antialiasing drift must pass, while every shape of real change — a one-pixel
// shift, a broad tint, or a single grossly different pixel — must still fail.
// A future change to the thresholds has to update these expectations on
// purpose.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'golden_comparator.dart';

const int _width = 200;
const int _height = 200;
const int _total = _width * _height;

/// Builds an opaque RGBA frame whose luminance is decided by [shade].
Uint8List _frame(int Function(int x, int y) shade) {
  final bytes = Uint8List(_total * 4);
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final i = (y * _width + x) * 4;
      final value = shade(x, y);
      bytes[i] = value;
      bytes[i + 1] = value;
      bytes[i + 2] = value;
      bytes[i + 3] = 255;
    }
  }
  return bytes;
}

/// White frame with a two-pixel dark "stem" — stands in for a glyph edge.
Uint8List _stemFrame({int stemX = 100, int height = 150}) => _frame((x, y) {
      final inStem = (x == stemX || x == stemX + 1) && y >= 20 && y < 20 + height;
      return inStem ? 0 : 255;
    });

GoldenDiffStats _stats(Uint8List test, Uint8List master) =>
    GoldenDiffStats.fromRgba(test, master);

void main() {
  test('identical frames are not a diff', () {
    final frame = _stemFrame();
    final stats = _stats(frame, Uint8List.fromList(frame));
    expect(stats.differingPixels, 0);
    expect(stats.hardPixels, 0);
    expect(stats.isAntialiasingJitter, isTrue);
  });

  test('scattered low-delta glyph-edge noise is host jitter', () {
    final master = _stemFrame();
    final test = Uint8List.fromList(master);
    // 60 edge pixels nudged by 1–14, the shape macOS 27.2 produces.
    for (var y = 20; y < 80; y++) {
      final i = (y * _width + 99) * 4;
      final delta = 1 + (y % 14);
      test[i] = 255 - delta;
      test[i + 1] = 255 - delta;
      test[i + 2] = 255 - delta;
    }
    final stats = _stats(test, master);
    expect(stats.differingPixels, 60);
    expect(stats.hardPixels, 0);
    expect(stats.grossPixels, 0);
    expect(stats.isAntialiasingJitter, isTrue);
  });

  test('a one-pixel layout shift fails', () {
    final master = _stemFrame();
    final test = _stemFrame(stemX: 101);
    final stats = _stats(test, master);
    // Both old and new stem columns now differ by the full 255.
    expect(stats.hardPixels, greaterThan(200));
    expect(stats.isAntialiasingJitter, isFalse);
  });

  test('a broad low-contrast tint fails', () {
    final master = _frame((x, y) => 255);
    final test = _frame((x, y) => 247); // Δ8 everywhere: invisible per pixel
    final stats = _stats(test, master);
    expect(stats.hardPixels, 0);
    expect(stats.differingFraction, 1.0);
    expect(stats.isAntialiasingJitter, isFalse);
  });

  test('a single gross pixel fails', () {
    final master = _frame((x, y) => 255);
    final test = Uint8List.fromList(master);
    const i = (50 * _width + 50) * 4;
    test[i] = 40; // Δ215 on red only
    final stats = _stats(test, master);
    expect(stats.grossPixels, 1);
    expect(stats.isAntialiasingJitter, isFalse);
  });

  test('too many low-delta pixels fail even without gross pixels', () {
    final master = _frame((x, y) => 255);
    // Nudge a fifth of the frame by Δ5 — under aaDelta, over the noise budget.
    final test = _frame((x, y) => y < _height ~/ 5 ? 250 : 255);
    final stats = _stats(test, master);
    expect(stats.hardPixels, 0);
    expect(stats.differingFraction, greaterThan(0.0025));
    expect(stats.isAntialiasingJitter, isFalse);
  });

  test('mismatched buffers are rejected', () {
    expect(
      () => GoldenDiffStats.fromRgba(Uint8List(8), Uint8List(12)),
      throwsArgumentError,
    );
  });
}
