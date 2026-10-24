// lib/core/protocol/events.dart
library;

/// Event model for every engine→client event (doc 03 §5).
/// Group A = agent lifecycle & streaming, Group B = session/runtime state,
/// Group C = extension_ui_request. Plain Dart — no codegen.
import 'messages.dart';

/// Event type name constants (the `type` field on the wire).
abstract class EventTypes {
  // Group A — agent lifecycle & streaming
  static const agentStart = 'agent_start';
  static const turnStart = 'turn_start';
  static const messageStart = 'message_start';
  static const messageUpdate = 'message_update';
  static const messageEnd = 'message_end';
  static const turnEnd = 'turn_end';
  static const agentEnd = 'agent_end';
  static const toolExecutionStart = 'tool_execution_start';
  static const toolExecutionUpdate = 'tool_execution_update';
  static const toolExecutionEnd = 'tool_execution_end';
  // Group B — session/runtime state
  static const queueUpdate = 'queue_update';
  static const subagentsUpdate = 'subagents_update';
  static const toolPermissionUpdate = 'tool_permission_update';
  static const compactionStart = 'compaction_start';
  static const compactionEnd = 'compaction_end';
  static const autoRetryStart = 'auto_retry_start';
  static const autoRetryEnd = 'auto_retry_end';
  static const sessionInfoChanged = 'session_info_changed';
  static const thinkingLevelChanged = 'thinking_level_changed';
  static const planModeChanged = 'plan_mode_changed';
  static const sessionsUpdate = 'sessions_update';
  // Group B — extensions (M6, behind feature flags)
  static const cronUpdate = 'cron_update';
  static const officeUpdate = 'office_update';
  // Group C — extension UI
  static const extensionUiRequest = 'extension_ui_request';
}

/// A parsed engine event: `type` plus the raw JSON payload.
/// The event router switches on [type] and reads fields from [json].
class EngineEvent {
  final String type;
  final Map<String, dynamic> json;
  const EngineEvent(this.type, this.json);
  factory EngineEvent.fromJson(Map<String, dynamic> json) {
    return EngineEvent(json['type'] as String? ?? '', json);
  }

  /// The `message` payload as a typed AgentMessage (when present).
  AgentMessage? get message {
    final raw = json['message'];
    if (raw is Map<String, dynamic>) return AgentMessage.fromJson(raw);
    return null;
  }
}

// ─── Shared payload types ────────────────────────────────────────
class UsageData {
  final int input;
  final int output;
  final int cacheRead;
  final int cacheWrite;
  final double? costTotal;
  const UsageData(
      {required this.input,
      required this.output,
      required this.cacheRead,
      required this.cacheWrite,
      this.costTotal});
  factory UsageData.fromJson(Map<String, dynamic> json) => UsageData(
        input: (json['input'] as num?)?.toInt() ?? 0,
        output: (json['output'] as num?)?.toInt() ?? 0,
        cacheRead: (json['cacheRead'] as num?)?.toInt() ?? 0,
        cacheWrite: (json['cacheWrite'] as num?)?.toInt() ?? 0,
        costTotal: (json['costTotal'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {
        'input': input,
        'output': output,
        'cacheRead': cacheRead,
        'cacheWrite': cacheWrite,
        if (costTotal != null) 'costTotal': costTotal,
      };
}

/// AssistantMessageEvent subtype carried on message_update
/// ("text_start" | "text_delta" | …). Free-form — the UI only keys on a few.
String? assistantMessageEventType(Map<String, dynamic> eventJson) =>
    eventJson['assistantMessageEvent'] is Map<String, dynamic>
        ? (eventJson['assistantMessageEvent'] as Map<String, dynamic>)['type']
            as String?
        : eventJson['assistantMessageEvent'] as String?;

// ─── Group B payload types ───────────────────────────────────────
class RuntimeSessionStatus {
  final String path;
  final String cwd;
  final String status; // running | needsInput
  final int pendingMessageCount;
  const RuntimeSessionStatus(
      {required this.path,
      required this.cwd,
      required this.status,
      required this.pendingMessageCount});
  factory RuntimeSessionStatus.fromJson(Map<String, dynamic> json) =>
      RuntimeSessionStatus(
        path: json['path'] as String? ?? '',
        cwd: json['cwd'] as String? ?? '',
        status: json['status'] as String? ?? 'running',
        pendingMessageCount:
            (json['pendingMessageCount'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'path': path,
        'cwd': cwd,
        'status': status,
        'pendingMessageCount': pendingMessageCount,
      };
}

class SubAgentRecord {
  final String id;
  final String subject;
  final String status; // running | completed | failed
  const SubAgentRecord(
      {required this.id, required this.subject, required this.status});
  factory SubAgentRecord.fromJson(Map<String, dynamic> json) => SubAgentRecord(
        id: json['id'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        status: json['status'] as String? ?? 'running',
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'subject': subject, 'status': status};
}

// ─── Group C — extension_ui_request ─────────────────────────────
/// UI request kinds on the wire:
/// confirm | select | question | input | editor | notify | setStatus | setWidget | setTitle
class ExtensionUiRequest {
  final String id; // request ID (separate namespace from command ids)
  final String method;
  final String? kind; // "permission" for tool approvals
  final String? toolName;
  final String? title;
  final String? message;
  final List<QuestionOption>? options; // select/question
  final bool? multiSelect;
  final String? notifyType; // info | warning | error
  final WorkflowInfo? workflow;
  final int? timeout; // seconds
  const ExtensionUiRequest({
    required this.id,
    required this.method,
    this.kind,
    this.toolName,
    this.title,
    this.message,
    this.options,
    this.multiSelect,
    this.notifyType,
    this.workflow,
    this.timeout,
  });
  factory ExtensionUiRequest.fromJson(Map<String, dynamic> json) =>
      ExtensionUiRequest(
        id: json['id'] as String? ?? '',
        method: json['method'] as String? ?? '',
        kind: json['kind'] as String?,
        toolName: json['toolName'] as String?,
        title: json['title'] as String?,
        message: json['message'] as String?,
        options: (json['options'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QuestionOption.fromJson)
            .toList(),
        multiSelect: json['multiSelect'] as bool?,
        notifyType: json['notifyType'] as String?,
        workflow: json['workflow'] is Map<String, dynamic>
            ? WorkflowInfo.fromJson(json['workflow'] as Map<String, dynamic>)
            : null,
        timeout: (json['timeout'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        if (kind != null) 'kind': kind,
        if (toolName != null) 'toolName': toolName,
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (options != null)
          'options': options!.map((o) => o.toJson()).toList(),
        if (multiSelect != null) 'multiSelect': multiSelect,
        if (notifyType != null) 'notifyType': notifyType,
        if (workflow != null) 'workflow': workflow!.toJson(),
        if (timeout != null) 'timeout': timeout,
      };
}

class QuestionOption {
  final String label;
  final String? description;
  const QuestionOption({required this.label, this.description});
  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        label: json['label'] as String? ?? '',
        description: json['description'] as String?,
      );
  Map<String, dynamic> toJson() =>
      {'label': label, if (description != null) 'description': description};
}

class WorkflowInfo {
  final String name;
  final List<dynamic>? phases;
  const WorkflowInfo({required this.name, this.phases});
  factory WorkflowInfo.fromJson(Map<String, dynamic> json) => WorkflowInfo(
        name: json['name'] as String? ?? '',
        phases: (json['phases'] as List<dynamic>?)?.toList(),
      );
  Map<String, dynamic> toJson() =>
      {'name': name, if (phases != null) 'phases': phases};
}

/// The command the app sends back in answer to an extension_ui_request.
class ExtensionUiResponse {
  final String id;
  final Map<String, dynamic> payload;
  const ExtensionUiResponse({required this.id, this.payload = const {}});
  Map<String, dynamic> toJson() =>
      {'type': 'extension_ui_response', 'id': id, ...payload};
}

// ─── Bridge control frames (bridge-owned envelope) ──────────────
class BridgeControlFrame {
  final String
      event; // connected | engine_exited | engine_failed | shutting_down | server_version | slow_client | engine_unavailable
  final int? clients;
  final int? code;
  final int? attempts;

  /// Server version string on `server_version` frames.
  final String? version;
  final String? ip;

  /// Why a command was refused on `engine_unavailable`: `starting` (no running
  /// engine yet) or `backlog` (engine alive, stdin queue full — retry).
  final String? reason;
  const BridgeControlFrame({
    required this.event,
    this.clients,
    this.code,
    this.attempts,
    this.version,
    this.ip,
    this.reason,
  });
  factory BridgeControlFrame.fromJson(Map<String, dynamic> json) =>
      BridgeControlFrame(
        event: json['event'] as String? ?? '',
        clients: (json['clients'] as num?)?.toInt(),
        code: (json['code'] as num?)?.toInt(),
        attempts: (json['attempts'] as num?)?.toInt(),
        version: json['version'] is String ? json['version'] as String : null,
        ip: json['ip'] as String?,
        reason: json['reason'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'type': 'bridge',
        'event': event,
        if (clients != null) 'clients': clients,
        if (code != null) 'code': code,
        if (attempts != null) 'attempts': attempts,
        if (version != null) 'version': version,
        if (ip != null) 'ip': ip,
        if (reason != null) 'reason': reason,
      };
}
