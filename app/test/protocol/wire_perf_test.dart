library;
import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/core/protocol/wire.dart' as wire;

void main() {
  test('handles 4MB line and thousands of lines quickly', () {
    final sw = Stopwatch()..start();
    final lines = <String>[];
    final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
    // A single 4 MiB line.
    final big = 'x' * (4 * 1024 * 1024);
    acc.feed('$big\n');
    expect(lines.length, 1);
    expect(lines.first.length, big.length);

    // Thousands of small lines.
    final many = List.generate(5000, (i) => '{"i":$i}').join('\n') + '\n';
    final lines2 = <String>[];
    final acc2 = wire.LineAccumulator(onLine: (line) => lines2.add(line));
    acc2.feed(many);
    expect(lines2.length, 5000);
    sw.stop();
    // Generous bound for CI machines.
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('accumulation bounded at 16 MiB', () {
    final lines = <String>[];
    final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
    acc.feed('a' * (20 * 1024 * 1024)); // no newline; oversized tail dropped
    expect(lines, isEmpty);
    acc.feed('\n');
    // dropped tail means nothing emitted
    expect(lines, isEmpty);
  });
}
