// lib/features/chat/providers/chat_providers.dart
library;
/// Chat state providers (doc 05 §4).
///
/// Single source of truth: `chatStateProvider` — a `StateNotifier<ChatState>`
/// fed by the pure event router (`event_router.dart`). Every inbound protocol
/// event is applied through `applyEvent`, so the UI can never diverge from
/// the wire. The selectors below expose slices under stable names.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/protocol/events.dart' as proto_events;
import '../../../core/protocol/responses.dart' as responses;
import 'event_router.dart' as er;

// ─── Core chat state ──────────────────────────────────────────────
final chatStateProvider = StateNotifierProvider<ChatStateNotifier, er.ChatState>((ref) {
  return ChatStateNotifier();
});

class ChatStateNotifier extends StateNotifier<er.ChatState> {
  ChatStateNotifier() : super(const er.ChatState());

  // ── Streaming render throttle (doc 06 §3: ~16 rebuilds/s) ──
  // message_update carries the FULL rebuilt message each time; re-rendering
  // at token speed wastes frames. Coalesce updates into at most ~16/s and
  // flush immediately on any other event (message_end, turn_end, …).
  static const _throttleInterval = Duration(milliseconds: 62);
  Timer? _flushTimer;
  Map<String, dynamic>? _pendingUpdate;
  DateTime _lastApply = DateTime.fromMillisecondsSinceEpoch(0);

  /// Route one inbound protocol event through the pure reducer.
  void applyEvent(String eventType, Map<String, dynamic> data) {
    if (!mounted) return;
    if (eventType == 'message_update') {
      final elapsed = DateTime.now().difference(_lastApply);
      if (elapsed < _throttleInterval) {
        _pendingUpdate = data; // keep only the newest
        _flushTimer ??= Timer(_throttleInterval - elapsed, _flushPendingUpdate);
        return;
      }
      _lastApply = DateTime.now();
      state = state.applyEvent(eventType, data);
      return;
    }
    // Any other event lands after the pending update — order preserved.
    if (_pendingUpdate != null) _flushPendingUpdate();
    state = state.applyEvent(eventType, data);
  }

  void _flushPendingUpdate() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final pending = _pendingUpdate;
    if (pending == null || !mounted) return;
    _pendingUpdate = null;
    _lastApply = DateTime.now();
    state = state.applyEvent('message_update', pending);
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  /// Apply a `get_transcript_page` response. Pages fetched backwards from
  /// `before` are prepended (deduped by entry id); a fresh page replaces.
  void loadTranscriptPage(responses.TranscriptPageResponse page) {
    if (!mounted) return;
    final mapped = page.entries
        .where((e) => e.type == 'message' && e.message != null)
        .map<er.UiMessage>((e) => er.UiMessage(
              id: e.id,
              role: (e.message is Map<String, dynamic>
                      ? (e.message as Map<String, dynamic>)['role']
                      : null) as String? ??
                  'assistant',
              content: e.message!,
            ))
        .toList();
    final prepend = state.messages.isNotEmpty &&
        (state.olderCursor == null || page.start < state.olderCursor!);
    List<er.UiMessage> merged;
    if (prepend) {
      final known = state.messages.map((m) => m.id).toSet();
      merged = [
        ...mapped.where((m) => !known.contains(m.id)),
        ...state.messages,
      ];
    } else {
      merged = mapped;
    }
    state = state.copyWith(
      messages: merged,
      olderCursor: page.start,
      hasMoreBefore: page.hasMore,
      isLoadingOlder: false,
      totalEntries: page.total,
    );
  }

  void setLoadingOlder(bool value) {
    if (!mounted) return;
    state = state.copyWith(isLoadingOlder: value);
  }

  /// Replace the transcript from a get_messages response.
  void loadMessages(List<Object> messages) {
    if (!mounted) return;
    state = state.copyWith(
      messages: messages.map(_uiMessageFromJson).toList(),
    );
  }

  /// Update session fields from a get_state response.
  void updateFromStateResponse(responses.SessionStateResponse response) {
    if (!mounted) return;
    state = state.copyWith(
      session: er.SessionState(
        model: response.model.id,
        modelProvider: response.model.provider,
        modelName: response.model.name ?? '',
        thinkingLevel: response.thinkingLevel,
        permissionMode: response.permissionMode,
        planMode: response.planMode,
        isStreaming: response.isStreaming,
        isCompacting: response.isCompacting,
        messageCount: response.messageCount,
        sessionName: response.sessionName ?? '',
        cwd: response.cwd ?? '',
        sessionId: response.sessionId,
        sessionFile: response.sessionFile ?? '',
      ),
    );
    // Keep old model string behavior for tests that read session.model.
  }

  /// Optimistic local user message (after a successful prompt RPC).
  void addLocalUserMessage(String text) {
    if (!mounted) return;
    state = state.copyWith(messages: [
      ...state.messages,
      er.UiMessage(
        id: 'local_${state.messages.length}_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text},
          ],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    ]);
  }

  void removeApproval(String id) {
    if (!mounted) return;
    final updated = Map<String, er.UiRequest>.from(state.approvals)..remove(id);
    state = state.copyWith(approvals: updated);
  }

  void reset() {
    if (!mounted) return;
    state = const er.ChatState();
  }
}

/// Build a UiMessage from a protocol AgentMessage JSON map (get_messages /
/// message_end shapes). Arrives complete — never streaming.
er.UiMessage _uiMessageFromJson(Object msg) {
  final json = msg is Map<String, dynamic> ? msg : <String, dynamic>{};
  return er.UiMessage(
    id: 'm${json['timestamp'] ?? json.hashCode}',
    role: json['role'] as String? ?? 'assistant',
    content: msg,
  );
}

// ─── Derived selectors (stable names for screens) ─────────────────
final messagesProvider = Provider<List<er.UiMessage>>((ref) => ref.watch(chatStateProvider).messages);
final toolCardsProvider = Provider<Map<String, er.ToolCardState>>((ref) => ref.watch(chatStateProvider).toolCards);
final queueProvider = Provider<er.QueueState>((ref) => ref.watch(chatStateProvider).queue);
final approvalsProvider = Provider<Map<String, er.UiRequest>>((ref) => ref.watch(chatStateProvider).approvals);
final sessionStateProvider = Provider<er.SessionState>((ref) => ref.watch(chatStateProvider).session);
final streamingUsageProvider = Provider<proto_events.UsageData?>((ref) => ref.watch(chatStateProvider).lastUsage);

// ─── Subagents strip (desktop SubagentPanel parity) ───────────────
final subagentsProvider = StateNotifierProvider<SubagentsNotifier, List<proto_events.SubAgentRecord>>((ref) {
  return SubagentsNotifier();
});

class SubagentsNotifier extends StateNotifier<List<proto_events.SubAgentRecord>> {
  SubagentsNotifier() : super([]);
  void update(List<proto_events.SubAgentRecord> agents) => state = agents;
  void clear() => state = [];
}

// ─── Background processes (desktop RuntimePanel parity) ──────────
final backgroundProcessesProvider = StateNotifierProvider<BackgroundProcessesNotifier, List<Map<String, dynamic>>>((ref) {
  return BackgroundProcessesNotifier();
});

class BackgroundProcessesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  BackgroundProcessesNotifier() : super([]);
  void update(List<Map<String, dynamic>> processes) => state = processes;
  void clear() => state = [];
}

// ─── Session stats (context usage — desktop StatusBar parity) ─────
class SessionStats {
  final int? tokens;
  final int contextWindow;
  final double? percent;
  const SessionStats({this.tokens, this.contextWindow = 0, this.percent});
  bool get hasData => contextWindow > 0;
}

final sessionStatsProvider = StateNotifierProvider<SessionStatsNotifier, SessionStats>((ref) {
  return SessionStatsNotifier();
});

class SessionStatsNotifier extends StateNotifier<SessionStats> {
  SessionStatsNotifier() : super(const SessionStats());
  void updateFromResponse(Map<String, dynamic> data) {
    final cu = data['contextUsage'];
    if (cu is! Map<String, dynamic>) return;
    state = SessionStats(
      tokens: (cu['tokens'] as num?)?.toInt(),
      contextWindow: (cu['contextWindow'] as num?)?.toInt() ?? 0,
      percent: (cu['percent'] as num?)?.toDouble(),
    );
  }

  void clear() => state = const SessionStats();
}

// ─── Slash commands (desktop Composer autocomplete parity) ────────
final slashCommandsProvider = StateNotifierProvider<SlashCommandsNotifier, List<Map<String, dynamic>>>((ref) {
  return SlashCommandsNotifier();
});

class SlashCommandsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  SlashCommandsNotifier() : super([]);
  void update(List<Map<String, dynamic>> commands) => state = commands;
  void clear() => state = [];

  List<Map<String, dynamic>> filter(String query) {
    final q = query.toLowerCase();
    return state.where((c) => (c['name'] as String? ?? '').toLowerCase().startsWith(q)).toList();
  }
}
