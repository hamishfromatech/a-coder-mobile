// lib/core/protocol/wire.dart
library;
/// NDJSON wire codec — LF-only framing, U+2028/2029 safe, multi-MB line support.
/// Mirrors the engine's jsonl.ts rules exactly (doc 03 §1).
/// Pure Dart — no Flutter dependency.
import 'dart:convert';
/// Split raw data into complete JSON lines on LF boundaries only.
/// Handles \r\n by stripping trailing \r. Skips empty lines.
/// U+2028/U+2029 inside strings are legal JSON and must NOT split records.
List<String> splitLines(String data) {
  final parts = data.split('\n');
  final lines = <String>[];
  for (final part in parts) {
    // Strip trailing \r before \n (engine does this too)
    final cleaned = part.endsWith('\r') ? part.substring(0, part.length - 1) : part;
    if (cleaned.isNotEmpty) {
      lines.add(cleaned);
    }
  }
  return lines;
}
/// Parse a single JSON line. Returns null for empty or malformed input.
Object? parseLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    // Malformed JSON — drop (per protocol rules)
    return null;
  }
}
/// Serialize a value to one JSON line terminated with LF.
String serializeLine(Object? value) => '${jsonEncode(value)}\n';
/// Line-based stream accumulator.
/// Buffers partial data and emits complete lines via [onLine].
/// Handles multi-MB lines without dropping the connection, and never
/// discards completed lines when an oversized tail arrives (16 MiB cap).
class LineAccumulator {
  static const int maxLineBytes = 16 * 1024 * 1024; // 16 MiB
  String _buffer = '';
  final void Function(String line) onLine;
  LineAccumulator({required this.onLine});
  /// Feed raw data into the accumulator. Complete lines go to [onLine].
  void feed(String data) {
    _buffer += data;
    // Extract complete lines first — never drop valid completed data.
    var idx = _buffer.indexOf('\n');
    while (idx >= 0) {
      var line = _buffer.substring(0, idx);
      _buffer = _buffer.substring(idx + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isNotEmpty) {
        onLine(line);
      }
      idx = _buffer.indexOf('\n');
    }
    // Only the incomplete remainder is left. If it exceeds the cap, drop it:
    // a single line this large is protocol garbage (max payload is 16 MiB).
    if (_buffer.length > maxLineBytes) {
      _buffer = '';
    }
  }
  /// Call when the stream ends — emits any remaining buffer as a final line.
  void flush() {
    var tail = _buffer;
    _buffer = '';
    if (tail.endsWith('\r')) {
      tail = tail.substring(0, tail.length - 1);
    }
    if (tail.trim().isNotEmpty) {
      onLine(tail.trim());
    }
  }
}