// The composer renders user messages optimistically; the engine echoes them
// back on message_start. The echo must replace the placeholder, not append.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

er.UiMessage _localEcho(String text, {String id = 'local_1'}) => er.UiMessage(
      id: id,
      role: 'user',
      content: {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    );

Map<String, dynamic> _engineUser(String text) => {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': text},
      ],
      'timestamp': 1234,
    };

void main() {
  test('engine user echo replaces the optimistic message', () {
    final state = er.ChatState(messages: [_localEcho('hello')]);
    final next = state.applyEvent('message_start', {
      'message': _engineUser('hello'),
    });
    expect(next.messages, hasLength(1));
    expect(next.messages.single.id.startsWith('local_'), isFalse);
    expect(er.messageText(next.messages.single.content), 'hello');
  });

  test('a different user message is appended normally', () {
    final state = er.ChatState(messages: [_localEcho('hello')]);
    final next = state.applyEvent('message_start', {
      'message': _engineUser('goodbye'),
    });
    expect(next.messages, hasLength(2));
    expect(next.messages.first.id, 'local_1');
  });

  test('history without an echo appends the user message', () {
    final next = const er.ChatState().applyEvent('message_start', {
      'message': _engineUser('from history'),
    });
    expect(next.messages, hasLength(1));
    expect(next.messages.single.role, 'user');
  });

  test('identical sends keep their order when echoed back', () {
    final state = er.ChatState(messages: [
      _localEcho('same', id: 'local_1'),
      _localEcho('same', id: 'local_2'),
    ]);
    final first = state.applyEvent('message_start', {
      'message': {..._engineUser('same'), 'timestamp': 1},
    });
    expect(first.messages.map((m) => m.id).toList(),
        [startsWith('m'), startsWith('local_2')]);
    final second = first.applyEvent('message_start', {
      'message': {..._engineUser('same'), 'timestamp': 2},
    });
    expect(second.messages, hasLength(2));
    expect(second.messages.every((m) => m.id.startsWith('m')), isTrue);
  });

  test('string and text-part content both read as text', () {
    expect(er.messageText('plain'), 'plain');
    expect(
      er.messageText({
        'content': [
          {'type': 'text', 'text': 'a'},
          {'type': 'image', 'data': 'x'},
          {'type': 'text', 'text': 'b'},
        ],
      }),
      'ab',
    );
  });
}
