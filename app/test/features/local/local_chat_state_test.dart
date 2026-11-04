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
}
