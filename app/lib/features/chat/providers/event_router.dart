// lib/features/chat/providers/event_router.dart
library;

/// Event router — the core reducer (doc 05 §4.1).
/// Maps every inbound JSON event to state mutations.
/// Pure function: (Event, State) → NewState. No side effects.
import '../../../core/protocol/events.dart' as proto;

// ─── UI State model ──────────────────────────────────────────────
class ChatState {
  final List<UiMessage> messages;
  final Map<String, ToolCardState> toolCards;
  final QueueState queue;
  final Map<String, UiRequest> approvals;
  final SessionState session;
  final proto.UsageData? lastUsage;
  final bool isStreaming;
  final int retryAttempt; // 0 = not retrying (auto_retry_start/end)
  final int retryMax;
  // ── Transcript paging (get_transcript_page) ──
  /// Entry index of the oldest loaded item; pass as `before` to page older.
  final int? olderCursor;
  final bool hasMoreBefore;
  final bool isLoadingOlder;
  final int totalEntries;
  const ChatState({
    this.messages = const [],
    this.toolCards = const {},
    this.queue = const QueueState(),
    this.approvals = const {},
    this.session = const SessionState(),
    this.lastUsage,
    this.isStreaming = false,
    this.retryAttempt = 0,
    this.retryMax = 0,
    this.olderCursor,
    this.hasMoreBefore = false,
    this.isLoadingOlder = false,
    this.totalEntries = 0,
  });
  bool get isRetrying => retryAttempt > 0;

  static const Object _unset = Object();

  ChatState copyWith({
    List<UiMessage>? messages,
    Map<String, ToolCardState>? toolCards,
    QueueState? queue,
    Map<String, UiRequest>? approvals,
    SessionState? session,
    proto.UsageData? lastUsage,
    bool? isStreaming,
    int? retryAttempt,
    int? retryMax,
    Object? olderCursor = _unset,
    bool? hasMoreBefore,
    bool? isLoadingOlder,
    int? totalEntries,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      toolCards: toolCards ?? this.toolCards,
      queue: queue ?? this.queue,
      approvals: approvals ?? this.approvals,
      session: session ?? this.session,
      lastUsage: lastUsage ?? this.lastUsage,
      isStreaming: isStreaming ?? this.isStreaming,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      retryMax: retryMax ?? this.retryMax,
      olderCursor: identical(olderCursor, _unset)
          ? this.olderCursor
          : olderCursor as int?,
      hasMoreBefore: hasMoreBefore ?? this.hasMoreBefore,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      totalEntries: totalEntries ?? this.totalEntries,
    );
  }

  ChatState applyEvent(String eventType, Map<String, dynamic> data) {
    return switch (eventType) {
      // ─── Group A: Agent lifecycle & streaming ──────────────
      'agent_start' => _onAgentStart(this, data),
      'turn_start' => _onTurnStart(this, data),
      'message_start' => _onMessageStart(this, data),
      'message_update' => _onMessageUpdate(this, data),
      'message_end' => _onMessageEnd(this, data),
      'turn_end' => _onTurnEnd(this, data),
      'agent_end' => _onAgentEnd(this, data),
      'tool_execution_start' => _onToolExecutionStart(this, data),
      'tool_execution_update' => _onToolExecutionUpdate(this, data),
      'tool_execution_end' => _onToolExecutionEnd(this, data),
      // ─── Group B: Session/runtime state ─────────────────────
      'queue_update' => _onQueueUpdate(this, data),
      'subagents_update' => _onSubagentsUpdate(this, data),
      'tool_permission_update' => _onToolPermissionUpdate(this, data),
      'compaction_start' => _onCompactionStart(this, data),
      'compaction_end' => _onCompactionEnd(this, data),
      'auto_retry_start' => _onAutoRetryStart(this, data),
      'auto_retry_end' => _onAutoRetryEnd(this, data),
      'session_info_changed' => _onSessionInfoChanged(this, data),
      'thinking_level_changed' => _onThinkingLevelChanged(this, data),
      'plan_mode_changed' => _onPlanModeChanged(this, data),
      'sessions_update' => this, // handled by separate provider
      // ─── Group C: Extension UI ──────────────────────────────
      'extension_ui_request' => _onExtensionUiRequest(this, data),
      // ─── Unknown events — ignore (forward-compat) ───────────
      _ => this,
    };
  }
}

class UiMessage {
  final String id; // toolCallId or message index
  final String role; // user | assistant | toolResult
  final Object content; // raw JSON message (renderers parse lazily)
  final bool isStreaming;
  const UiMessage(
      {required this.id,
      required this.role,
      required this.content,
      this.isStreaming = false});
  UiMessage copyWith(
          {String? id, String? role, Object? content, bool? isStreaming}) =>
      UiMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class ToolCardState {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
  final Object? partialResult; // from tool_execution_update
  final Object? result; // from tool_execution_end
  final bool isError;
  final bool isComplete;
  const ToolCardState({
    required this.toolCallId,
    required this.toolName,
    this.args = const {},
    this.partialResult,
    this.result,
    this.isError = false,
    this.isComplete = false,
  });
  ToolCardState copyWith({
    Map<String, dynamic>? args,
    Object? partialResult,
    Object? result,
    bool? isError,
    bool? isComplete,
  }) =>
      ToolCardState(
        toolCallId: toolCallId,
        toolName: toolName,
        args: args ?? this.args,
        partialResult: partialResult ?? this.partialResult,
        result: result ?? this.result,
        isError: isError ?? this.isError,
        isComplete: isComplete ?? this.isComplete,
      );
}

class QueueState {
  final List<String> steering;
  final List<String> followUp;
  const QueueState({this.steering = const [], this.followUp = const []});
  bool get isEmpty => steering.isEmpty && followUp.isEmpty;
  bool get isNotEmpty => !isEmpty;
  QueueState copyWith({List<String>? steering, List<String>? followUp}) =>
      QueueState(
        steering: steering ?? this.steering,
        followUp: followUp ?? this.followUp,
      );
}

class SessionState {
  final String model;
  final String thinkingLevel;
  final String permissionMode;
  final bool planMode;
  final bool isStreaming;
  final bool isCompacting;
  final int messageCount;
  final String sessionName; // from get_state (session_info_changed)
  final String cwd; // from get_state
  final String sessionId;
  final String sessionFile; // absolute path — used for export/switch
  final String
      modelProvider; // for set_model (doc 03: set_model takes provider + modelId)
  final String modelName; // display name (desktop chip shows this)
  const SessionState({
    this.model = '',
    this.thinkingLevel = 'off',
    this.permissionMode = 'default',
    this.planMode = false,
    this.isStreaming = false,
    this.isCompacting = false,
    this.messageCount = 0,
    this.sessionName = '',
    this.cwd = '',
    this.sessionId = '',
    this.sessionFile = '',
    this.modelProvider = '',
    this.modelName = '',
  });
  SessionState copyWith({
    String? model,
    String? thinkingLevel,
    String? permissionMode,
    bool? planMode,
    bool? isStreaming,
    bool? isCompacting,
    int? messageCount,
    String? sessionName,
    String? cwd,
    String? sessionId,
    String? sessionFile,
    String? modelProvider,
    String? modelName,
  }) =>
      SessionState(
        model: model ?? this.model,
        thinkingLevel: thinkingLevel ?? this.thinkingLevel,
        permissionMode: permissionMode ?? this.permissionMode,
        planMode: planMode ?? this.planMode,
        isStreaming: isStreaming ?? this.isStreaming,
        isCompacting: isCompacting ?? this.isCompacting,
        messageCount: messageCount ?? this.messageCount,
        sessionName: sessionName ?? this.sessionName,
        cwd: cwd ?? this.cwd,
        sessionId: sessionId ?? this.sessionId,
        sessionFile: sessionFile ?? this.sessionFile,
        modelProvider: modelProvider ?? this.modelProvider,
        modelName: modelName ?? this.modelName,
      );
}

class UiRequest {
  final String id;
  final String method; // confirm | select | question | input | editor | notify
  final String? kind; // "permission" for tool approvals
  final String? toolName;
  final String? title;
  final String? message;
  final List<Map<String, dynamic>>? options;
  final bool? multiSelect;
  final String?
      workflowName; // run_workflow approvals — rule: run_workflow(<name>)
  final int? timeout; // seconds
  const UiRequest({
    required this.id,
    required this.method,
    this.kind,
    this.toolName,
    this.title,
    this.message,
    this.options,
    this.multiSelect,
    this.workflowName,
    this.timeout,
  });
}

// ─── Event handlers (pure functions) ─────────────────────────────
ChatState _onAgentStart(ChatState state, Map<String, dynamic> data) {
  return state.copyWith(
      isStreaming: true, session: state.session.copyWith(isStreaming: true));
}

ChatState _onTurnStart(ChatState state, Map<String, dynamic> data) {
  return state; // turn_start is a visual marker, handled in UI
}

ChatState _onMessageStart(ChatState state, Map<String, dynamic> data) {
  final msg = data['message'];
  if (msg is! Map<String, dynamic>) return state;
  final role = msg['role'] as String? ?? '';
  final id = 'm${state.messages.length}_${msg['timestamp'] ?? ''}';
  if (role == 'assistant') {
    // New assistant message — streaming placeholder, replaced on update/end.
    return state.copyWith(
      messages: [
        ...state.messages,
        UiMessage(id: id, role: 'assistant', content: msg, isStreaming: true)
      ],
      isStreaming: true,
    );
  }
  // user / toolResult messages arrive complete.
  return state.copyWith(messages: [
    ...state.messages,
    UiMessage(id: id, role: role, content: msg)
  ]);
}

ChatState _onMessageUpdate(ChatState state, Map<String, dynamic> data) {
  final msg = data['message'];
  if (msg is! Map<String, dynamic>) return state;
  if (msg['role'] != 'assistant') return state;
  // Replace the in-flight assistant message wholesale (desktop pattern).
  final updated = UiMessage(
    id: state.messages
        .lastWhere((m) => m.isStreaming,
            orElse: () => const UiMessage(
                id: 'streaming', role: 'assistant', content: {}))
        .id,
    role: 'assistant',
    content: msg,
    isStreaming: true,
  );
  var foundIdx = -1;
  for (var i = state.messages.length - 1; i >= 0; i--) {
    if (state.messages[i].isStreaming &&
        state.messages[i].role == 'assistant') {
      foundIdx = i;
      break;
    }
  }
  final newMessages = List<UiMessage>.from(state.messages);
  if (foundIdx >= 0) {
    newMessages[foundIdx] = updated;
  } else {
    newMessages.add(updated);
  }
  return state.copyWith(messages: newMessages);
}

ChatState _onMessageEnd(ChatState state, Map<String, dynamic> data) {
  var foundIdx = -1;
  for (var i = state.messages.length - 1; i >= 0; i--) {
    if (state.messages[i].isStreaming &&
        state.messages[i].role == 'assistant') {
      foundIdx = i;
      break;
    }
  }
  if (foundIdx >= 0) {
    final newMessages = List<UiMessage>.from(state.messages);
    final msg = data['message'];
    // Prefer the finalized message from the event; fall back to current content.
    newMessages[foundIdx] = newMessages[foundIdx].copyWith(
      content:
          msg is Map<String, dynamic> ? msg : newMessages[foundIdx].content,
      isStreaming: false,
    );
    return state.copyWith(messages: newMessages);
  }
  return state;
}

ChatState _onTurnEnd(ChatState state, Map<String, dynamic> data) {
  final usageData = data['usage'];
  if (usageData is Map<String, dynamic>) {
    final usage = proto.UsageData.fromJson(usageData);
    return state.copyWith(
        lastUsage: usage, session: state.session.copyWith(isStreaming: false));
  }
  return state.copyWith(session: state.session.copyWith(isStreaming: false));
}

ChatState _onAgentEnd(ChatState state, Map<String, dynamic> data) {
  return state.copyWith(
      isStreaming: false, session: state.session.copyWith(isStreaming: false));
}

ChatState _onToolExecutionStart(ChatState state, Map<String, dynamic> data) {
  final toolCallId = data['toolCallId'];
  final toolName = data['toolName'];
  if (toolCallId is! String || toolName is! String) return state;
  final args = data['args'] is Map<String, dynamic>
      ? data['args'] as Map<String, dynamic>
      : <String, dynamic>{};
  return state.copyWith(
    toolCards: {
      ...state.toolCards,
      toolCallId:
          ToolCardState(toolCallId: toolCallId, toolName: toolName, args: args),
    },
  );
}

ChatState _onToolExecutionUpdate(ChatState state, Map<String, dynamic> data) {
  final toolCallId = data['toolCallId'];
  if (toolCallId is! String) return state;
  final existing = state.toolCards[toolCallId];
  if (existing != null) {
    return state.copyWith(
      toolCards: {
        ...state.toolCards,
        toolCallId: existing.copyWith(partialResult: data['partialResult'])
      },
    );
  }
  return state;
}

ChatState _onToolExecutionEnd(ChatState state, Map<String, dynamic> data) {
  final toolCallId = data['toolCallId'];
  if (toolCallId is! String) return state;
  final isError = data['isError'] as bool? ?? false;
  final existing = state.toolCards[toolCallId];
  if (existing != null) {
    return state.copyWith(
      toolCards: {
        ...state.toolCards,
        toolCallId: existing.copyWith(
            isComplete: true, isError: isError, result: data['result']),
      },
    );
  }
  return state;
}

ChatState _onQueueUpdate(ChatState state, Map<String, dynamic> data) {
  final steering =
      (data['steering'] as List<dynamic>? ?? []).whereType<String>().toList();
  final followUp =
      (data['followUp'] as List<dynamic>? ?? []).whereType<String>().toList();
  return state.copyWith(
      queue: QueueState(steering: steering, followUp: followUp));
}

ChatState _onSubagentsUpdate(ChatState state, Map<String, dynamic> data) {
  // Handled by a separate provider in a later milestone
  return state;
}

ChatState _onToolPermissionUpdate(ChatState state, Map<String, dynamic> data) {
  final waiting = data['waiting'] as bool? ?? true;
  final id =
      (data['requestId'] ?? data['id'] ?? data['approvalId'])?.toString();
  if (waiting == false) {
    if (id != null && state.approvals.containsKey(id)) {
      final updated = Map<String, UiRequest>.from(state.approvals)..remove(id);
      return state.copyWith(approvals: updated);
    }
    return state.copyWith(approvals: {});
  }
  return state;
}

ChatState _onCompactionStart(ChatState state, Map<String, dynamic> data) {
  return state.copyWith(session: state.session.copyWith(isCompacting: true));
}

ChatState _onCompactionEnd(ChatState state, Map<String, dynamic> data) {
  return state.copyWith(session: state.session.copyWith(isCompacting: false));
}

ChatState _onAutoRetryStart(ChatState state, Map<String, dynamic> data) {
  // Desktop: "Retrying (attempt N/max)…" banner while the engine backs off.
  final attempt = (data['attempt'] as num?)?.toInt() ?? 1;
  final max = (data['maxAttempts'] as num?)?.toInt() ?? 0;
  return state.copyWith(
      isStreaming: true, retryAttempt: attempt, retryMax: max);
}

ChatState _onAutoRetryEnd(ChatState state, Map<String, dynamic> data) {
  return state.copyWith(retryAttempt: 0, retryMax: 0);
}

ChatState _onSessionInfoChanged(ChatState state, Map<String, dynamic> data) {
  // Update session name (handled by UI title bar)
  return state;
}

ChatState _onThinkingLevelChanged(ChatState state, Map<String, dynamic> data) {
  final level = data['level'] as String? ?? state.session.thinkingLevel;
  return state.copyWith(session: state.session.copyWith(thinkingLevel: level));
}

ChatState _onPlanModeChanged(ChatState state, Map<String, dynamic> data) {
  final enabled = data['enabled'] as bool? ?? false;
  return state.copyWith(session: state.session.copyWith(planMode: enabled));
}

ChatState _onExtensionUiRequest(ChatState state, Map<String, dynamic> data) {
  final request = proto.ExtensionUiRequest.fromJson(data);
  if (request.id.isEmpty) return state;
  // Add to pending approvals (one at a time in v1 — engine serializes)
  return state.copyWith(
    approvals: {
      ...state.approvals,
      request.id: UiRequest(
        id: request.id,
        method: request.method,
        kind: request.kind,
        toolName: request.toolName,
        title: request.title,
        message: request.message,
        options: request.options?.map((o) => o.toJson()).toList(),
        multiSelect: request.multiSelect,
        timeout: request.timeout,
      ),
    },
  );
}

// ─── Extension UI Response builder ──────────────────────────────
/// Build the extension_ui_response wire payload for an action.
/// action: "allow" | "deny" | "always_allow" (permission confirmations).
/// For "always_allow" the caller must send add_session_allow_rules FIRST,
/// then this confirmed:true response (doc 03 §4.5).
Map<String, dynamic> handleExtensionUiResponse(
    UiRequest request, String action) {
  switch (action) {
    case 'allow':
    case 'always_allow':
      return {
        'type': 'extension_ui_response',
        'id': request.id,
        'confirmed': true
      };
    case 'deny':
      return {
        'type': 'extension_ui_response',
        'id': request.id,
        'confirmed': false
      };
    default:
      return {'type': 'extension_ui_response', 'id': request.id};
  }
}
