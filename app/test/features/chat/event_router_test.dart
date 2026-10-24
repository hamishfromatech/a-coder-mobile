// test/features/chat/event_router_test.dart
library;
/// Unit tests for the event router (doc 08 §4 — pure-core testing).

import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

void main() {
  group('event router', () {
    late er.ChatState state;

    setUp(() {
      state = const er.ChatState();
    });

    test('agent_start sets isStreaming to true', () {
      final newState = state.applyEvent('agent_start', {});
      expect(newState.isStreaming, isTrue);
    });

    test('message_start appends user message', () {
      final newState = state.applyEvent('message_start', {'message': {'role': 'user', 'content': [], 'timestamp': 0}});
      expect(newState.messages.length, equals(1));
      expect(newState.messages.first.role, equals('user'));
    });

    test('message_update replaces in-flight assistant message', () {
      // First add a streaming message
      var s = state.applyEvent('message_start', {'message': {'role': 'assistant', 'content': [], 'timestamp': 0}});
      s = s.applyEvent('message_update', {'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': 'hello'}], 'timestamp': 1}, 'assistantMessageEvent': {'type': 'text_delta'}});
      expect(s.messages.length, equals(1));
    });

    test('message_end finalizes streaming message (stream continues until agent_end)', () {
      var s = state.applyEvent('message_start', {'message': {'role': 'assistant', 'content': [], 'timestamp': 0}});
      s = s.applyEvent('message_update', {'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': 'done'}], 'timestamp': 1}, 'assistantMessageEvent': null});
      s = s.applyEvent('message_end', {'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': 'done'}], 'timestamp': 2}});
      // A turn may contain several messages — only turn_end/agent_end stop streaming.
      expect(s.isStreaming, isTrue);
      expect(s.messages.last.isStreaming, isFalse); // this message finalized
    });

    test('turn_end captures usage data', () {
      final s = state.applyEvent('turn_end', {'usage': {'input': 1000, 'output': 500, 'cacheRead': 200, 'cacheWrite': 300, 'costTotal': 0.05}});
      expect(s.lastUsage, isNotNull);
      expect(s.lastUsage!.input, equals(1000));
    });

    test('agent_end sets isStreaming to false', () {
      var s = state.applyEvent('agent_start', {});
      s = s.applyEvent('agent_end', {'willRetry': false});
      expect(s.isStreaming, isFalse);
    });

    test('tool_execution_start creates tool card', () {
      final s = state.applyEvent('tool_execution_start', {'toolCallId': 't1', 'toolName': 'bash', 'args': {'command': 'npm test'}});
      expect(s.toolCards['t1'], isNotNull);
      expect(s.toolCards['t1']!.toolName, equals('bash'));
    });

    test('tool_execution_update adds partial result', () {
      var s = state.applyEvent('tool_execution_start', {'toolCallId': 't1', 'toolName': 'bash', 'args': {}});
      s = s.applyEvent('tool_execution_update', {'toolCallId': 't1', 'toolName': 'bash', 'partialResult': 'running...'});
      expect(s.toolCards['t1']!.partialResult, equals('running...'));
    });

    test('tool_execution_end marks card complete', () {
      var s = state.applyEvent('tool_execution_start', {'toolCallId': 't1', 'toolName': 'edit', 'args': {}});
      s = s.applyEvent('tool_execution_end', {'toolCallId': 't1', 'toolName': 'edit', 'isError': false});
      expect(s.toolCards['t1']!.isComplete, isTrue);
    });

    test('queue_update sets queue state', () {
      final s = state.applyEvent('queue_update', {'steering': ['item1'], 'followUp': ['item2', 'item3']});
      expect(s.queue.steering.length, equals(1));
      expect(s.queue.followUp.length, equals(2));
    });

    test('extension_ui_request adds approval', () {
      final s = state.applyEvent('extension_ui_request', {
        'id': 'u1',
        'method': 'confirm',
        'kind': 'permission',
        'toolName': 'bash',
        'title': 'Allow bash?',
        'message': 'npm test',
      });
      expect(s.approvals['u1'], isNotNull);
      expect(s.approvals['u1']!.method, equals('confirm'));
    });

    test('compaction_start sets compacting flag', () {
      final s = state.applyEvent('compaction_start', {'reason': 'token_limit'});
      expect(s.session.isCompacting, isTrue);
    });

    test('compaction_end clears compacting flag', () {
      var s = state.applyEvent('compaction_start', {});
      s = s.applyEvent('compaction_end', {});
      expect(s.session.isCompacting, isFalse);
    });

    test('unknown events are ignored (forward-compat)', () {
      final originalState = state;
      final s = state.applyEvent('some_future_event_type', {'data': 'value'});
      expect(identical(s.messages, originalState.messages), isTrue); // same list reference
    });

    test('thinking_level_changed updates session', () {
      final s = state.applyEvent('thinking_level_changed', {'level': 'high'});
      expect(s.session.thinkingLevel, equals('high'));
    });
  });

  group('extension UI response handler', () {
    test('allow produces confirmed:true', () {
      final req = const er.UiRequest(id: 'u1', method: 'confirm');
      final json = er.handleExtensionUiResponse(req, 'allow');
      expect(json['confirmed'], isTrue);
    });

    test('deny produces confirmed:false', () {
      final req = const er.UiRequest(id: 'u1', method: 'confirm');
      final json = er.handleExtensionUiResponse(req, 'deny');
      expect(json['confirmed'], isFalse);
    });

    test('always_allow produces confirmed:true (after add_session_allow_rules)', () {
      final req = const er.UiRequest(id: 'u1', method: 'confirm');
      final json = er.handleExtensionUiResponse(req, 'always_allow');
      expect(json['confirmed'], isTrue);
    });
  });
}
