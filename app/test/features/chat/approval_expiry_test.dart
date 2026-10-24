import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/features/chat/providers/event_router.dart' as er;

void main() {
  test('tool_permission_update waiting:false clears pending approvals', () {
    var state = const er.ChatState();
    state = state.applyEvent('extension_ui_request', {
      'id': 'u1',
      'method': 'confirm',
      'kind': 'permission',
      'toolName': 'bash',
      'message': 'npm test',
      'timeout': 60,
    });
    expect(state.approvals, isNotEmpty);
    state = state.applyEvent('tool_permission_update', {'waiting': false});
    expect(state.approvals, isEmpty);
  });

  test('UiRequest carries timeout', () {
    final state = const er.ChatState().applyEvent('extension_ui_request', {
      'id': 'u2',
      'method': 'confirm',
      'kind': 'permission',
      'toolName': 'bash',
      'message': 'npm test',
      'timeout': 30,
    });
    expect(state.approvals['u2']!.timeout, equals(30));
  });
}
