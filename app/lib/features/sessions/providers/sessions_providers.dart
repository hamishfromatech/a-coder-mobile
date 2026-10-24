// lib/features/sessions/providers/sessions_providers.dart
library;
/// Session list + background sessions providers (doc 05 §4).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/protocol/events.dart' show RuntimeSessionStatus;
import '../../../core/protocol/responses.dart' show RpcSessionInfo;
final sessionsListProvider = StateNotifierProvider<SessionsListNotifier, List<RpcSessionInfo>>((ref) {
  return SessionsListNotifier();
});
class SessionsListNotifier extends StateNotifier<List<RpcSessionInfo>> {
  SessionsListNotifier() : super([]);
  Future<void> refresh() async {
    // In production: call get_state + list_sessions via RpcClient
    debugPrint('[sessions] refreshing');
    // state = await client.listSessions();
  }
  void addSession(RpcSessionInfo session) {
    state = [session, ...state];
  }

  /// Replace the whole list from a list_sessions response.
  void replaceAll(List<RpcSessionInfo> sessions) {
    state = sessions;
  }
  void removeSession(String path) {
    state = state.where((s) => s.path != path).toList();
  }
}
final backgroundSessionsProvider = StateNotifierProvider<BackgroundSessionsNotifier, List<RuntimeSessionStatus>>((ref) {
  return BackgroundSessionsNotifier();
});
class BackgroundSessionsNotifier extends StateNotifier<List<RuntimeSessionStatus>> {
  BackgroundSessionsNotifier() : super([]);
  void update(List<RuntimeSessionStatus> sessions) {
    state = sessions;
  }
  void remove(String path) {
    state = state.where((s) => s.path != path).toList();
  }
}