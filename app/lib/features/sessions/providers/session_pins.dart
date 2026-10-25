// Session pins — desktop `lib/session-pins.ts` parity, persisted locally.
//
// Pins are a client-side preference (session paths), not engine state, so they
// survive bridge restarts and reconnects.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/protocol/responses.dart' show RpcSessionInfo;

final sessionPinsProvider =
    StateNotifierProvider<SessionPinsNotifier, Set<String>>((ref) {
  return SessionPinsNotifier();
});

class SessionPinsNotifier extends StateNotifier<Set<String>> {
  static const prefsKey = 'sessionPins';

  SessionPinsNotifier() : super(<String>{}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(prefsKey) ?? const <String>[]).toSet();
  }

  Future<void> toggle(String path) async {
    if (path.isEmpty) return;
    final next = {...state};
    if (!next.remove(path)) next.add(path);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, next.toList());
  }

  bool isPinned(String path) => state.contains(path);
}

/// Desktop ordering: pins first, then date buckets (newest first).
List<(String, List<RpcSessionInfo>)> groupSessions(
  List<RpcSessionInfo> sessions,
  Set<String> pins,
) {
  final pinned = <RpcSessionInfo>[];
  final today = <RpcSessionInfo>[];
  final yesterday = <RpcSessionInfo>[];
  final week = <RpcSessionInfo>[];
  final earlier = <RpcSessionInfo>[];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  for (final session in sessions) {
    if (pins.contains(session.path)) {
      pinned.add(session);
      continue;
    }
    final modified = DateTime.tryParse(session.modified) ?? now;
    final day = DateTime(modified.year, modified.month, modified.day);
    final age = todayStart.difference(day).inDays;
    if (age <= 0) {
      today.add(session);
    } else if (age == 1) {
      yesterday.add(session);
    } else if (age < 7) {
      week.add(session);
    } else {
      earlier.add(session);
    }
  }

  return [
    if (pinned.isNotEmpty) ('Pinned', pinned),
    if (today.isNotEmpty) ('Today', today),
    if (yesterday.isNotEmpty) ('Yesterday', yesterday),
    if (week.isNotEmpty) ('This week', week),
    if (earlier.isNotEmpty) ('Earlier', earlier),
  ];
}
