// Pins + date grouping (desktop session-list ordering).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/core/protocol/responses.dart' show RpcSessionInfo;
import 'package:acoder_mobile/features/sessions/providers/session_pins.dart';

RpcSessionInfo _session(String path, DateTime modified) => RpcSessionInfo(
      path: path,
      id: path,
      cwd: '/work',
      created: modified.toIso8601String(),
      modified: modified.toIso8601String(),
      messageCount: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('groups pins first, then date buckets', () {
    final now = DateTime.now();
    final sessions = [
      _session('/s/today', now),
      _session('/s/yesterday', now.subtract(const Duration(days: 1))),
      _session('/s/week', now.subtract(const Duration(days: 3))),
      _session('/s/old', now.subtract(const Duration(days: 30))),
      _session('/s/pinned', now.subtract(const Duration(days: 60))),
    ];
    final groups = groupSessions(sessions, {'/s/pinned'});
    expect(groups.map((g) => g.$1).toList(),
        ['Pinned', 'Today', 'Yesterday', 'This week', 'Earlier']);
    expect(groups.first.$2.single.path, '/s/pinned');
    expect(groups.last.$2.single.path, '/s/old');
  });

  test('pin toggle persists and is idempotent', () async {
    final notifier = SessionPinsNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.isPinned('/s/a'), isFalse);
    await notifier.toggle('/s/a');
    expect(notifier.isPinned('/s/a'), isTrue);
    await notifier.toggle('/s/a');
    expect(notifier.isPinned('/s/a'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(SessionPinsNotifier.prefsKey), isEmpty);
  });
}
