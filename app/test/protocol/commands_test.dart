// Command builder serialization (doc 03 §4).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/protocol/commands.dart';

void main() {
  test('rewind serializes steps and correlates with an id', () {
    final command = RewindCommand(steps: 2);
    final wire = command.toWireJson();

    expect(wire['type'], 'rewind');
    expect(wire['steps'], 2);
    expect(wire['id'], isA<String>());
    expect(command.toLine(), endsWith('\n'));
  });

  test('rewind omits steps when unset (engine defaults to 1)', () {
    expect(RewindCommand().toJson().containsKey('steps'), isFalse);
  });

  test('prompt toLine is one NDJSON record, newline-terminated', () {
    final line = PromptCommand(message: 'hello').toLine();
    expect(line.endsWith('\n'), isTrue);
    expect(line.trim().contains('\n'), isFalse);
    final decoded = jsonDecode(line.trim()) as Map<String, dynamic>;
    expect(decoded['type'], 'prompt');
    expect(decoded['message'], 'hello');
  });
}
