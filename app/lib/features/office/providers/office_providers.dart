// Your Office state (roster, huddles, activity) — plan M6.2.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' as responses;

/// Roster snapshot from `office_list` / `office_update`.
final officeSnapshotProvider =
    StateNotifierProvider<OfficeSnapshotNotifier, responses.OfficeSnapshot>(
        (ref) {
  return OfficeSnapshotNotifier();
});

class OfficeSnapshotNotifier extends StateNotifier<responses.OfficeSnapshot> {
  OfficeSnapshotNotifier() : super(const responses.OfficeSnapshot());

  void update(responses.OfficeSnapshot snapshot) => state = snapshot;
  void clear() => state = const responses.OfficeSnapshot();

  /// Refresh statuses from an `office_update` that only carries statuses.
  void setStatuses(Map<String, String> statuses) {
    state = responses.OfficeSnapshot(
      coworkers: state.coworkers,
      statuses: statuses,
      huddles: state.huddles,
      errands: state.errands,
      pendingPrompts: state.pendingPrompts,
    );
  }
}

/// The currently open huddle payload (null = roster).
final officeHuddleProvider =
    StateNotifierProvider<OfficeHuddleNotifier, responses.OfficeHuddlePayload?>(
        (ref) {
  return OfficeHuddleNotifier();
});

class OfficeHuddleNotifier
    extends StateNotifier<responses.OfficeHuddlePayload?> {
  OfficeHuddleNotifier() : super(null);

  void update(responses.OfficeHuddlePayload payload) => state = payload;
  void clear() => state = null;

  /// Merge an `office_huddle_delta` into the open room. Deltas for another
  /// room are ignored (the viewer is per-huddle).
  void applyDelta(Map<String, dynamic> delta) {
    final current = state;
    if (current == null) return;
    final huddleId = delta['huddleId'] as String? ?? current.huddleId;
    if (huddleId != current.huddleId) return;

    final appended = (delta['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final messages = <Map<String, dynamic>>[
      ...current.messages,
      ...appended,
    ];
    // Keep the log bounded like the engine does (cap ~500 lines).
    final bounded = messages.length > 500
        ? messages.sublist(messages.length - 500)
        : messages;

    final working = Map<String, bool>.of(current.working);
    final rawWorking = delta['working'];
    if (rawWorking is Map) {
      rawWorking.forEach((key, value) => working['$key'] = value == true);
    }

    state = responses.OfficeHuddlePayload(
      huddleId: current.huddleId,
      data: {...current.data, 'messages': bounded},
      working: working,
    );
  }
}

/// Recent coworker activity frames (bounded).
final officeActivityProvider =
    StateNotifierProvider<OfficeActivityNotifier, List<Map<String, dynamic>>>(
        (ref) {
  return OfficeActivityNotifier();
});

class OfficeActivityNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  OfficeActivityNotifier() : super(const []);
  static const _max = 200;

  void add(Map<String, dynamic> activity) {
    final next = [...state, activity];
    state = next.length > _max ? next.sublist(next.length - _max) : next;
  }

  void clear() => state = const [];
}
