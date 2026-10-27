import 'package:acoder_mobile/features/sessions/providers/sessions_providers.dart';
import 'package:acoder_mobile/core/protocol/responses.dart' show RpcSessionInfo;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replace and remove sessions', () {
    final notifier = SessionsListNotifier();
    final s1 = RpcSessionInfo(
        id: '1',
        path: '/a',
        cwd: '/a',
        created: DateTime.now().toIso8601String(),
        modified: DateTime.now().toIso8601String(),
        messageCount: 0);
    notifier.replaceAll([s1]);
    expect(notifier.state.length, 1);
    notifier.removeSession('/a');
    expect(notifier.state.length, 0);
  });
}
