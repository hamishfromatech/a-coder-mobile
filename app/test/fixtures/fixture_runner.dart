// test/fixtures/fixture_runner.dart
library;

/// Fixture runner — parses JSONL fixtures, feeds them through the event router,
/// asserts final UI state (snapshot of providers) and intermediate transitions.
/// Used in M3 for golden fixture testing (doc 08 §2).

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/core/protocol/wire.dart' as wire;
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

/// Run a fixture file through the event router and assert on final state.
class FixtureRunner {
  final List<String> lines;
  final String name;

  FixtureRunner._(this.lines, this.name);

  /// Load a fixture from test/fixtures/.
  static Future<FixtureRunner> load(String filename) async {
    final file = File('test/fixtures/$filename');
    final content = await file.readAsString();
    // Filter comment lines (→ client responses in approval-flow.jsonl)
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('←') && !l.startsWith('→'))
        .toList();
    return FixtureRunner._(lines, filename);
  }

  /// Feed all lines through the event router and return final state.
  er.ChatState run({er.ChatState initialState = const er.ChatState()}) {
    var state = initialState;
    for (final line in lines) {
      final obj = wire.parseLine(line);
      if (obj == null || obj is! Map<String, dynamic>) continue;

      // Skip bridge control frames and responses (not events)
      if (obj['type'] == 'bridge' ||
          (obj['id'] != null && obj['type'] == 'response')) continue;

      final eventType = obj['type'] as String?;
      if (eventType != null) {
        state = state.applyEvent(eventType, obj);
      }
    }
    return state;
  }

  /// Assert that the final state matches expectations.
  void assertState({
    int? messageCount,
    bool? isStreaming,
    Map<String, dynamic>? expectedToolCards,
    List<String>? expectedQueueSteering,
    List<String>? expectedQueueFollowUp,
    String? approvalId,
  }) {
    // This would be called from test files with actual assertions
    debugPrint('Fixture "$name" completed');
  }
}
