import 'package:acoder_mobile/features/local/local_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith accepts int progress without a cast failure', () {
    const state = LocalChatState();
    expect(state.copyWith(progress: 1).progress, 1.0);
    expect(state.copyWith(progress: 0).progress, 0.0);
    expect(state.copyWith(progress: 0.25).progress, 0.25);
  });
}
