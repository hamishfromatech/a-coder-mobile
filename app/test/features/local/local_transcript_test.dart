// Transcript serialization round-trips, including empty thinking fields and
// unknown-shape tolerance, so saved conversations survive upgrades.

import 'package:acoder_mobile/features/local/local_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toMap/fromMap round-trips user and assistant turns', () {
    const messages = [
      LocalChatMessage(role: LocalChatRole.user, text: 'Hello'),
      LocalChatMessage(
        role: LocalChatRole.assistant,
        text: 'The answer is 4.',
        thinking: '2+2 = 4',
      ),
      LocalChatMessage(role: LocalChatRole.user, text: '🎤 Voice message'),
    ];

    final restored = [
      for (final map in [for (final m in messages) m.toMap()])
        LocalChatMessage.fromMap(map),
    ];

    expect(restored.length, 3);
    expect(restored[0].role, LocalChatRole.user);
    expect(restored[0].text, 'Hello');
    expect(restored[0].thinking, '');
    expect(restored[1].role, LocalChatRole.assistant);
    expect(restored[1].text, 'The answer is 4.');
    expect(restored[1].thinking, '2+2 = 4');
    expect(restored[2].text, '🎤 Voice message');
  });

  test('fromMap tolerates legacy entries without a thinking field', () {
    final message = LocalChatMessage.fromMap({
      'role': 'assistant',
      'text': 'ok',
    });

    expect(message.thinking, '');
    expect(message.role, LocalChatRole.assistant);
  });
}