// test/features/chat/chat_state_notifier_test.dart
library;
/// Unit tests for the Riverpod chat-state wiring (M3): events routed through
/// ChatStateNotifier produce the same states the pure router produces, plus
/// response-driven transcript loading and approval removal.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/protocol/responses.dart' as responses;
import 'package:acoder_mobile/features/chat/providers/chat_providers.dart';
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  test('applyEvent routes through the pure router', () {
    final notifier = container.read(chatStateProvider.notifier);

    notifier.applyEvent('agent_start', {});
    expect(container.read(chatStateProvider).isStreaming, isTrue);

    notifier.applyEvent('agent_end', {'willRetry': false});
    expect(container.read(chatStateProvider).isStreaming, isFalse);
  });

  test('loadMessages replaces the transcript', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.applyEvent('agent_start', {});
    notifier.loadMessages([
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hi'},
        ],
        'timestamp': 1,
      },
      {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'hello'},
        ],
        'timestamp': 2,
      },
    ]);

    final state = container.read(chatStateProvider);
    expect(state.messages.length, equals(2));
    expect(state.messages[0].role, equals('user'));
    expect(state.messages[1].role, equals('assistant'));
    expect(state.isStreaming, isTrue); // untouched by loadMessages
  });

  test('updateFromStateResponse fills session fields', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.updateFromStateResponse(const responses.SessionStateResponse(
      model: responses.StateModelRef(provider: 'anthropic', id: 'claude-3.5-sonnet', name: 'Claude 3.5 Sonnet'),
      thinkingLevel: 'medium',
      permissionMode: 'plan',
      planMode: true,
      isStreaming: false,
      isCompacting: false,
      steeringMode: 'all',
      followUpMode: 'all',
      sessionId: 's1',
      sessionName: 'fix the login bug',
      autoCompactionEnabled: true,
      compactionAutoContinue: false,
      messageCount: 12,
      pendingMessageCount: 0,
      cwd: '/home/project-a',
    ));

    final session = container.read(chatStateProvider).session;
    expect(session.model, equals('claude-3.5-sonnet'));
    expect(session.modelName, equals('Claude 3.5 Sonnet'));
    expect(session.modelProvider, equals('anthropic'));
    expect(session.thinkingLevel, equals('medium'));
    expect(session.planMode, isTrue);
    expect(session.sessionName, equals('fix the login bug'));
    expect(session.cwd, equals('/home/project-a'));
    expect(session.sessionFile, isEmpty);
  });

  test('addLocalUserMessage appends a user bubble', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.addLocalUserMessage('hi');
    final messages = container.read(messagesProvider);
    expect(messages.length, equals(1));
    expect(messages.first.role, equals('user'));
  });

  test('removeApproval drops the answered request', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.applyEvent('extension_ui_request', {
      'id': 'u1',
      'method': 'confirm',
      'kind': 'permission',
      'toolName': 'bash',
      'message': 'npm test',
    });
    expect(container.read(approvalsProvider).length, equals(1));

    notifier.removeApproval('u1');
    expect(container.read(approvalsProvider), isEmpty);
  });

  test('selectors expose the same objects as the core state', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.applyEvent('tool_execution_start', {'toolCallId': 't1', 'toolName': 'bash', 'args': {'command': 'npm test'}});
    notifier.applyEvent('queue_update', {'steering': ['a'], 'followUp': []});

    final er.ChatState core = container.read(chatStateProvider);
    expect(container.read(toolCardsProvider), same(core.toolCards));
    expect(container.read(queueProvider), same(core.queue));
  });

  test('auto_retry sets and clears the retry banner state', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.applyEvent('auto_retry_start', {'attempt': 1, 'maxAttempts': 3});
    var state = container.read(chatStateProvider);
    expect(state.isRetrying, isTrue);
    expect(state.retryAttempt, equals(1));
    expect(state.retryMax, equals(3));

    notifier.applyEvent('auto_retry_end', {});
    state = container.read(chatStateProvider);
    expect(state.isRetrying, isFalse);
  });

  test('reset clears everything', () {
    final notifier = container.read(chatStateProvider.notifier);
    notifier.applyEvent('agent_start', {});
    notifier.applyEvent('tool_execution_start', {'toolCallId': 't1', 'toolName': 'bash', 'args': {}});
    notifier.reset();
    final state = container.read(chatStateProvider);
    expect(state.isStreaming, isFalse);
    expect(state.toolCards, isEmpty);
    expect(state.messages, isEmpty);
  });
}

// Keep the er import referenced (type used in annotations above).
// ignore: unused_element
typedef _KeepEr = er.UiMessage;
