import 'package:acoder_mobile/features/local/local_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith accepts int progress without a cast failure', () {
    const state = LocalChatState();
    expect(state.copyWith(progress: 1).progress, 1.0);
    expect(state.copyWith(progress: 0).progress, 0.0);
    expect(state.copyWith(progress: 0.25).progress, 0.25);
  });

  test('assistant messages keep thinking separate from the answer', () {
    const message = LocalChatMessage(
      role: LocalChatRole.assistant,
      text: 'answer',
      thinking: 'reasoning',
    );
    expect(message.text, 'answer');
    expect(message.thinking, 'reasoning');
    expect(message.copyWith(text: 'new').thinking, 'reasoning');
  });

  test('splitThinking lifts inline reasoning without eating answer chars', () {
    final split = LocalChatController.splitThinking(
      answer: '2+2 is 4.\u003C/think\u003EThe answer is 4.',
      thinking: '',
    );
    expect(split.thinking, '2+2 is 4.');
    expect(split.answer, 'The answer is 4.');
  });

  test('splitThinking keeps channel thinking and trims the answer', () {
    final split = LocalChatController.splitThinking(
      answer: '  The answer is 4.  ',
      thinking: '  channel reasoning  ',
    );
    expect(split.thinking, 'channel reasoning');
    expect(split.answer, 'The answer is 4.');
  });

  test('splitThinking passes through answers with no marker', () {
    final split = LocalChatController.splitThinking(
      answer: 'plain answer',
      thinking: '',
    );
    expect(split.thinking, '');
    expect(split.answer, 'plain answer');
  });
}
