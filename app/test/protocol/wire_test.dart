// test/protocol/wire_test.dart
library;
/// Unit tests for the NDJSON wire codec (doc 08 §4).

import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/core/protocol/wire.dart' as wire;

void main() {
  group('splitLines', () {
    test('splits on LF only', () {
      expect(wire.splitLines('{"a":1}\n{"b":2}\n'), equals(['{"a":1}', '{"b":2}']));
    });

    test('handles \\r\\n by stripping trailing \\r', () {
      expect(wire.splitLines('{"a":1}\r\n{"b":2}\r\n'), equals(['{"a":1}', '{"b":2}']));
    });

    test('skips empty lines', () {
      expect(wire.splitLines('{"a":1}\n\n{"b":2}\n'), equals(['{"a":1}', '{"b":2}']));
    });

    test('does NOT split on U+2028/U+2029 inside strings', () {
      // These are legal JSON string characters
      const input = '{"text":"hello\u{2028}world"}\n{"type":"next"}';
      expect(wire.splitLines(input), equals(['{"text":"hello\u{2028}world"}', '{"type":"next"}']));
    });

    test('handles single line without trailing newline', () {
      expect(wire.splitLines('{"no-newline"}'), equals(['{"no-newline"}']));
    });

    test('returns empty list for empty string', () {
      expect(wire.splitLines(''), equals(<String>[]));
    });
  });

  group('parseLine', () {
    test('parses valid JSON', () {
      final result = wire.parseLine('{"type":"message_start","message":{}}');
      expect(result, isA<Map>());
      expect((result as Map)['type'], equals('message_start'));
    });

    test('returns null for empty string', () {
      expect(wire.parseLine(''), isNull);
    });

    test('returns null for malformed JSON', () {
      final result = wire.parseLine('{invalid}');
      expect(result, isNull);
    });
  });

  group('serializeLine', () {
    test('adds trailing newline', () {
      expect(wire.serializeLine({'type': 'test'}), equals('{"type":"test"}\n'));
    });
  });

  group('LineAccumulator', () {
    test('yields complete lines on feed', () {
      final lines = <String>[];
      final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
      acc.feed('{"a":1}\n{"b":2}\n');
      expect(lines, equals(['{"a":1}', '{"b":2}']));
    });

    test('buffers partial data until newline', () {
      final lines = <String>[];
      final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
      acc.feed('{"partial');
      expect(lines, isEmpty);
      acc.feed(':1}\n');
      expect(lines, equals(['{"partial:1}']));
    });

    test('flushes remaining buffer', () {
      final lines = <String>[];
      final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
      acc.feed('{"not": "finished"}');
      expect(lines, isEmpty);
      acc.flush();
      expect(lines, equals(['{"not": "finished"}']));
    });

    test('handles mixed \\n and \\r\\n', () {
      final lines = <String>[];
      final acc = wire.LineAccumulator(onLine: (line) => lines.add(line));
      acc.feed('{"a":1}\r\n{"b":2}\n');
      expect(lines, equals(['{"a":1}', '{"b":2}']));
    });
  });
}
