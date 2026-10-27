// lib/core/protocol/responses.dart
library;

/// Typed response classes for every command (doc 03 §4).
class Response {
  final String id;
  final String type = 'response';
  final bool success;
  final String? error; // present when success:false
  final Map<String, dynamic>? data; // command-specific payload
  const Response(
      {required this.id, required this.success, this.error, this.data});
  factory Response.fromJson(Map<String, dynamic> json) {
    return Response(
      id: json['id'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'success': success,
        if (error != null) 'error': error,
        if (data != null) 'data': data,
      };
}

// ─── Command-specific response shapes ────────────────────────────
/// Model reference as returned by get_state — an OBJECT, not a string
/// (desktop App.tsx syncEngineState: `model?: { provider, id, name? }`).
class StateModelRef {
  final String provider;
  final String id;
  final String? name;
  const StateModelRef({required this.provider, required this.id, this.name});
  factory StateModelRef.fromJson(dynamic json) {
    if (json is String) {
      // Tolerate engines that send a bare id string.
      return StateModelRef(provider: '', id: json);
    }
    if (json is Map<String, dynamic>) {
      return StateModelRef(
        provider: json['provider'] as String? ?? '',
        id: json['id'] as String? ?? '',
        name: json['name'] as String?,
      );
    }
    return const StateModelRef(provider: '', id: '');
  }
}

class SessionStateResponse {
  final StateModelRef model;
  final String thinkingLevel; // "off"|"minimal"|"low"|"medium"|"high"
  final String permissionMode; // "default"|"plan"|"auto"
  final bool planMode;
  final bool isStreaming;
  final bool isCompacting;
  final String steeringMode; // "all" | "one-at-a-time"
  final String followUpMode; // "all" | "one-at-a-time"
  final String? cwd;
  final String? sessionFile;
  final String sessionId;
  final String? sessionName;
  final bool autoCompactionEnabled;
  final bool compactionAutoContinue;
  final int messageCount;
  final int pendingMessageCount;
  const SessionStateResponse({
    required this.model,
    required this.thinkingLevel,
    required this.permissionMode,
    required this.planMode,
    required this.isStreaming,
    required this.isCompacting,
    required this.steeringMode,
    required this.followUpMode,
    this.cwd,
    this.sessionFile,
    required this.sessionId,
    this.sessionName,
    required this.autoCompactionEnabled,
    required this.compactionAutoContinue,
    required this.messageCount,
    required this.pendingMessageCount,
  });
  factory SessionStateResponse.fromJson(Map<String, dynamic> json) =>
      SessionStateResponse(
        model: StateModelRef.fromJson(json['model']),
        thinkingLevel: json['thinkingLevel'] as String? ?? 'off',
        permissionMode: json['permissionMode'] as String? ?? 'default',
        planMode: json['planMode'] as bool? ?? false,
        isStreaming: json['isStreaming'] as bool? ?? false,
        isCompacting: json['isCompacting'] as bool? ?? false,
        steeringMode: json['steeringMode'] as String? ?? 'all',
        followUpMode: json['followUpMode'] as String? ?? 'all',
        cwd: json['cwd'] as String?,
        sessionFile: json['sessionFile'] as String?,
        sessionId: json['sessionId'] as String? ?? '',
        sessionName: json['sessionName'] as String?,
        autoCompactionEnabled: json['autoCompactionEnabled'] as bool? ?? false,
        compactionAutoContinue:
            json['compactionAutoContinue'] as bool? ?? false,
        messageCount: json['messageCount'] as int? ?? 0,
        pendingMessageCount: json['pendingMessageCount'] as int? ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'model': model,
        'thinkingLevel': thinkingLevel,
        'permissionMode': permissionMode,
        'planMode': planMode,
        'isStreaming': isStreaming,
        'isCompacting': isCompacting,
        'steeringMode': steeringMode,
        'followUpMode': followUpMode,
        if (cwd != null) 'cwd': cwd,
        if (sessionFile != null) 'sessionFile': sessionFile,
        'sessionId': sessionId,
        if (sessionName != null) 'sessionName': sessionName,
        'autoCompactionEnabled': autoCompactionEnabled,
        'compactionAutoContinue': compactionAutoContinue,
        'messageCount': messageCount,
        'pendingMessageCount': pendingMessageCount,
      };
}

class SetModelResponse {
  final String id;
  final String name;
  final String provider;
  final int? contextWindow;
  final int? maxTokens;
  final bool? reasoning;
  const SetModelResponse(
      {required this.id,
      required this.name,
      required this.provider,
      this.contextWindow,
      this.maxTokens,
      this.reasoning});
  factory SetModelResponse.fromJson(Map<String, dynamic> json) =>
      SetModelResponse(
        id: json['id'] as String,
        name: json['name'] as String,
        provider: json['provider'] as String,
        contextWindow: json['contextWindow'] as int?,
        maxTokens: json['maxTokens'] as int?,
        reasoning: json['reasoning'] as bool?,
      );
}

class ClearQueueResponse {
  final List<String> steering;
  final List<String> followUp;
  const ClearQueueResponse({required this.steering, required this.followUp});
  factory ClearQueueResponse.fromJson(Map<String, dynamic> json) =>
      ClearQueueResponse(
        steering: (json['steering'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        followUp: (json['followUp'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class QueueRemoveResponse {
  final bool removed;
  const QueueRemoveResponse({required this.removed});
  factory QueueRemoveResponse.fromJson(Map<String, dynamic> json) =>
      QueueRemoveResponse(removed: json['removed'] as bool);
}

class StopWorkflowRunResponse {
  final bool stopped;
  const StopWorkflowRunResponse({required this.stopped});
  factory StopWorkflowRunResponse.fromJson(Map<String, dynamic> json) =>
      StopWorkflowRunResponse(stopped: json['stopped'] as bool);
}

class NewSessionResponse {
  final bool? cancelled;
  const NewSessionResponse({this.cancelled});
  factory NewSessionResponse.fromJson(Map<String, dynamic> json) =>
      NewSessionResponse(cancelled: json['cancelled'] as bool?);
}

class SwitchSessionResponse {
  final bool? cancelled;
  final bool? reattached;
  final Map<String, dynamic>?
      snapshot; // {running, needsInput, pendingMessageCount}
  const SwitchSessionResponse({this.cancelled, this.reattached, this.snapshot});
  factory SwitchSessionResponse.fromJson(Map<String, dynamic> json) =>
      SwitchSessionResponse(
        cancelled: json['cancelled'] as bool?,
        reattached: json['reattached'] as bool?,
        snapshot: json['snapshot'] as Map<String, dynamic>?,
      );
}

class ListSessionsResponse {
  final List<RpcSessionInfo> sessions;
  const ListSessionsResponse({required this.sessions});
  factory ListSessionsResponse.fromJson(Map<String, dynamic> json) =>
      ListSessionsResponse(
        sessions: (json['sessions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(RpcSessionInfo.fromJson)
            .toList(),
      );
}

class RpcSessionInfo {
  final String path;
  final String id;
  final String cwd;
  final String? name;
  final String? parentSessionPath;
  final String created; // ISO date string
  final String modified; // ISO date string
  final int messageCount;
  final String? firstMessage;
  const RpcSessionInfo(
      {required this.path,
      required this.id,
      required this.cwd,
      this.name,
      this.parentSessionPath,
      required this.created,
      required this.modified,
      required this.messageCount,
      this.firstMessage});
  factory RpcSessionInfo.fromJson(Map<String, dynamic> json) => RpcSessionInfo(
        path: json['path'] as String,
        id: json['id'] as String,
        cwd: json['cwd'] as String,
        name: json['name'] as String?,
        parentSessionPath: json['parentSessionPath'] as String?,
        created: json['created'] as String,
        modified: json['modified'] as String,
        messageCount: json['messageCount'] as int? ?? 0,
        firstMessage: json['firstMessage'] as String?,
      );
}

class GetMessagesResponse {
  final List<Object> messages; // AgentMessage[] (parsed from JSON)
  const GetMessagesResponse({required this.messages});
  factory GetMessagesResponse.fromJson(Map<String, dynamic> json) =>
      GetMessagesResponse(
        messages:
            (json['messages'] as List<dynamic>? ?? []).cast<Object>().toList(),
      );
}

/// One stored session entry (`get_transcript_page`). Only `type == "message"`
/// entries carry an AgentMessage; other types (compaction, custom) are
/// bookkeeping the mobile transcript does not render.
class TranscriptEntry {
  final String id;
  final String? parentId;
  final String type;
  final String timestamp;
  final Object? message;
  final String? summary;
  const TranscriptEntry(
      {required this.id,
      this.parentId,
      required this.type,
      required this.timestamp,
      this.message,
      this.summary});
  factory TranscriptEntry.fromJson(Map<String, dynamic> json) =>
      TranscriptEntry(
        id: json['id'] as String? ?? '',
        parentId: json['parentId'] as String?,
        type: json['type'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
        message: json['message'],
        summary: json['summary'] as String?,
      );
}

class TranscriptPageResponse {
  final List<TranscriptEntry> entries;
  final int total;
  final int start;
  final int end;
  final bool hasMore;
  const TranscriptPageResponse(
      {required this.entries,
      required this.total,
      required this.start,
      required this.end,
      required this.hasMore});
  factory TranscriptPageResponse.fromJson(Map<String, dynamic> json) =>
      TranscriptPageResponse(
        entries: (json['entries'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TranscriptEntry.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
        hasMore: json['hasMore'] as bool? ?? false,
      );
}

class AttachmentResponse {
  final String id;
  final String mimeType;
  final int bytes;
  final String data; // base64
  const AttachmentResponse(
      {required this.id,
      required this.mimeType,
      required this.bytes,
      required this.data});
  factory AttachmentResponse.fromJson(Map<String, dynamic> json) =>
      AttachmentResponse(
        id: json['id'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        data: json['data'] as String? ?? '',
      );
}

// ─── Cron ────────────────────────────────────────────────────────
class CronJob {
  final String id;
  final String name;
  final String prompt;
  final Map<String, dynamic> schedule;
  final bool enabled;
  final String cwd;
  final int? lastRunAt;
  final int? nextRunAt;
  final String? lastStatus;
  final Map<String, dynamic>? lastTriage;
  final String? lastError;
  final bool isolated;
  final int revision;
  const CronJob({
    required this.id,
    required this.name,
    required this.prompt,
    required this.schedule,
    required this.enabled,
    required this.cwd,
    this.lastRunAt,
    this.nextRunAt,
    this.lastStatus,
    this.lastTriage,
    this.lastError,
    this.isolated = true,
    this.revision = 1,
  });
  factory CronJob.fromJson(Map<String, dynamic> json) => CronJob(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '(untitled)',
        prompt: json['prompt'] as String? ?? '',
        schedule: json['schedule'] is Map<String, dynamic>
            ? json['schedule'] as Map<String, dynamic>
            : <String, dynamic>{},
        enabled: json['enabled'] as bool? ?? false,
        cwd: json['cwd'] as String? ?? '',
        lastRunAt: (json['lastRunAt'] as num?)?.toInt(),
        nextRunAt: (json['nextRunAt'] as num?)?.toInt(),
        lastStatus: json['lastStatus'] as String?,
        lastTriage: json['lastTriage'] is Map
            ? Map<String, dynamic>.from(json['lastTriage'] as Map)
            : null,
        lastError: json['lastError'] as String?,
        isolated: json['isolated'] as bool? ?? true,
        revision: (json['revision'] as num?)?.toInt() ?? 1,
      );

  /// Human schedule label ("daily 09:00", "every 30m", …).
  String get scheduleLabel {
    final kind = schedule['kind'] as String? ?? '';
    return switch (kind) {
      'every' => 'every ${schedule['minutes'] ?? '?'}m',
      'daily' => 'daily ${schedule['time'] ?? ''}',
      'weekly' =>
        'weekly ${(schedule['days'] as List<dynamic>? ?? const []).join(',')} @ ${schedule['time'] ?? ''}',
      'once' => 'once',
      'event' => 'on ${schedule['trigger'] ?? 'event'}',
      _ => kind.isEmpty ? 'manual' : kind,
    };
  }
}

class CronRun {
  final String id;
  final String jobId;
  final String jobName;
  final String trigger; // schedule | manual | event
  final String delivery; // session | background
  final String execution; // session | subagent
  final int startedAt;
  final int? finishedAt;
  final String status; // running | ok | error | timeout
  final String? error;
  final String? summary;
  final String? sessionFile;
  final Map<String, dynamic>? triage;
  final Map<String, String> variables;
  final String? model;
  final String? modelSource;
  final String? subagentId;
  final String? outputFile;
  final String? worktreePath;

  const CronRun({
    required this.id,
    required this.jobId,
    required this.jobName,
    required this.trigger,
    required this.delivery,
    this.execution = 'session',
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.error,
    this.summary,
    this.sessionFile,
    this.triage,
    this.variables = const {},
    this.model,
    this.modelSource,
    this.subagentId,
    this.outputFile,
    this.worktreePath,
  });

  factory CronRun.fromJson(Map<String, dynamic> json) => CronRun(
        id: json['id'] as String? ?? '',
        jobId: json['jobId'] as String? ?? '',
        jobName: json['jobName'] as String? ?? '',
        trigger: json['trigger'] as String? ?? 'schedule',
        delivery: json['delivery'] as String? ?? 'session',
        execution: json['execution'] as String? ?? 'session',
        startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
        finishedAt: (json['finishedAt'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'running',
        error: json['error'] as String?,
        summary: json['summary'] as String?,
        sessionFile: json['sessionFile'] as String?,
        triage: json['triage'] is Map<String, dynamic>
            ? json['triage'] as Map<String, dynamic>
            : null,
        variables: (json['variables'] as Map?)?.map(
              (key, value) => MapEntry('$key', '$value'),
            ) ??
            const {},
        model: json['model'] as String?,
        modelSource: json['modelSource'] as String?,
        subagentId: json['subagentId'] as String?,
        outputFile: json['outputFile'] as String?,
        worktreePath: json['worktreePath'] as String?,
      );
}

// ─── Your Office (read-mostly) ───────────────────────────────────
class Coworker {
  final String id;
  final String name;
  final String handle;
  final String? title;
  final String? description;
  final String? model;
  final String? voice;
  final String autonomy;
  const Coworker({
    required this.id,
    required this.name,
    required this.handle,
    this.title,
    this.description,
    this.model,
    this.voice,
    this.autonomy = 'assist',
  });
  factory Coworker.fromJson(Map<String, dynamic> json) => Coworker(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String?,
        model: json['model'] as String?,
        voice: json['voice'] as String?,
        autonomy: json['autonomy']?.toString() ?? 'assist',
      );
}

class HuddleSummary {
  final String id;
  final String name;
  final List<String> members;
  final String? preview;
  final int? lastActive;
  final bool pinned;
  const HuddleSummary({
    required this.id,
    required this.name,
    required this.members,
    this.preview,
    this.lastActive,
    this.pinned = false,
  });
  factory HuddleSummary.fromJson(Map<String, dynamic> json) => HuddleSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        members: (json['members'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        preview: json['preview'] as String?,
        lastActive: (json['lastActive'] as num?)?.toInt(),
        pinned: json['pinned'] as bool? ?? false,
      );
}

class OfficeErrand {
  final String id;
  final String coworkerId;
  final String name;
  final String prompt;
  final bool continuity;
  final Map<String, dynamic> schedule;
  final String delivery; // dm | huddle
  final String? huddleId;
  final bool enabled;
  const OfficeErrand({
    required this.id,
    required this.coworkerId,
    required this.name,
    required this.prompt,
    this.continuity = true,
    this.schedule = const {},
    this.delivery = 'dm',
    this.huddleId,
    this.enabled = true,
  });
  factory OfficeErrand.fromJson(Map<String, dynamic> json) => OfficeErrand(
        id: json['id'] as String? ?? '',
        coworkerId: json['coworkerId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        continuity: json['continuity'] as bool? ?? true,
        schedule: json['schedule'] is Map<String, dynamic>
            ? json['schedule'] as Map<String, dynamic>
            : <String, dynamic>{},
        delivery: json['delivery'] as String? ?? 'dm',
        huddleId: json['huddleId'] as String?,
        enabled: json['enabled'] as bool? ?? true,
      );

  String get scheduleLabel {
    final kind = schedule['kind'] as String?;
    switch (kind) {
      case 'every':
        return 'every ${(schedule['minutes'] as num?)?.toInt() ?? 0}m';
      case 'daily':
        return 'daily ${schedule['time'] ?? ''}';
      case 'once':
        final at = (schedule['at'] as num?)?.toInt();
        if (at == null) return 'once';
        final when = DateTime.fromMillisecondsSinceEpoch(at);
        String two(int n) => n.toString().padLeft(2, '0');
        return 'once ${when.year}-${two(when.month)}-${two(when.day)} '
            '${two(when.hour)}:${two(when.minute)}';
      default:
        return kind ?? '';
    }
  }
}

class OfficeSnapshot {
  final List<Coworker> coworkers;
  final Map<String, String> statuses; // coworkerId → status
  final List<HuddleSummary> huddles;
  final List<OfficeErrand> errands;
  final List<Map<String, dynamic>> pendingPrompts;
  const OfficeSnapshot({
    this.coworkers = const [],
    this.statuses = const {},
    this.huddles = const [],
    this.errands = const [],
    this.pendingPrompts = const [],
  });
  factory OfficeSnapshot.fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['statuses'];
    final statuses = <String, String>{};
    if (rawStatuses is Map) {
      rawStatuses.forEach((key, value) {
        statuses['$key'] = value is Map
            ? (value['status'] ?? value['state'] ?? value['kind'] ?? '')
                .toString()
            : '$value';
      });
    }
    return OfficeSnapshot(
      coworkers: (json['coworkers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Coworker.fromJson)
          .toList(),
      statuses: statuses,
      huddles: (json['huddles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HuddleSummary.fromJson)
          .toList(),
      errands: (json['errands'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OfficeErrand.fromJson)
          .toList(),
      pendingPrompts: (json['pendingPrompts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
  bool get isEmpty =>
      coworkers.isEmpty &&
      huddles.isEmpty &&
      errands.isEmpty &&
      pendingPrompts.isEmpty;
}

class OfficeHuddlePayload {
  final String huddleId;
  final Map<String, dynamic> data;
  final Map<String, bool> working;
  const OfficeHuddlePayload({
    required this.huddleId,
    this.data = const {},
    this.working = const {},
  });
  factory OfficeHuddlePayload.fromJson(Map<String, dynamic> json) =>
      OfficeHuddlePayload(
        huddleId: json['huddleId'] as String? ?? '',
        data: json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const {},
        working: (json['working'] as Map?)?.map(
              (key, value) => MapEntry('$key', value == true),
            ) ??
            const {},
      );

  /// Messages as stored by the engine (`data.messages`), raw shape.
  List<Map<String, dynamic>> get messages =>
      (data['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
}

class BashResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool? cancelled;
  const BashResult(
      {required this.stdout,
      required this.stderr,
      required this.exitCode,
      this.cancelled});
  factory BashResult.fromJson(Map<String, dynamic> json) => BashResult(
        stdout: json['stdout'] as String? ?? '',
        stderr: json['stderr'] as String? ?? '',
        exitCode: json['exitCode'] as int? ?? 0,
        cancelled: json['cancelled'] as bool?,
      );
}

class CompactionResult {
  final Object? result;
  final bool? aborted;
  final String? errorMessage;
  const CompactionResult({this.result, this.aborted, this.errorMessage});
  factory CompactionResult.fromJson(Map<String, dynamic> json) =>
      CompactionResult(
        result: json['result'],
        aborted: json['aborted'] as bool?,
        errorMessage: json['errorMessage'] as String?,
      );
}

class GetAvailableModelsResponse {
  final List<Map<String, dynamic>> models; // Model[] (parsed from JSON)
  const GetAvailableModelsResponse({required this.models});
  factory GetAvailableModelsResponse.fromJson(Map<String, dynamic> json) =>
      GetAvailableModelsResponse(
        models: (json['models'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}

class SetThinkingLevelResponse {
  final String level; // "off"|"minimal"|"low"|"medium"|"high"
  const SetThinkingLevelResponse({required this.level});
  factory SetThinkingLevelResponse.fromJson(Map<String, dynamic> json) =>
      SetThinkingLevelResponse(
        level: json['level'] as String,
      );
}

class AddSessionAllowRulesResponse {
  final List<String> rules; // e.g. ["bash(npm test)"]
  const AddSessionAllowRulesResponse({required this.rules});
  factory AddSessionAllowRulesResponse.fromJson(Map<String, dynamic> json) =>
      AddSessionAllowRulesResponse(
        rules: (json['rules'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}
