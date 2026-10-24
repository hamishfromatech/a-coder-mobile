// lib/core/protocol/commands.dart
library;
/// Typed command builders — mirror desktop-app/src/lib/rpc.ts (doc 03 §4).
/// Wire shape: `{"id": "<uuid>", "type": "<command>", ...payload}`
import 'dart:convert' show jsonEncode;
import 'package:uuid/uuid.dart';
const Uuid _uuid = Uuid();
abstract class RpcCommand {
  String get type;
  Map<String, dynamic> toJson();
  /// Correlation id — generated per command instance.
  String get id;
  /// Full wire object: {"id": ..., ...payload}
  Map<String, dynamic> toWireJson() => {'id': id, ...toJson()};
  /// Serialize to one NDJSON line (LF-terminated).
  String toLine() => '${jsonEncode(toWireJson())}\n';
}
mixin _GeneratedId implements RpcCommand {
  @override
  String get id => _uuid.v4();
}
// ─── 4.1 Prompting & queue ──────────────────────────────────────
class PromptCommand extends RpcCommand with _GeneratedId {
  final List<Map<String, dynamic>>? images; // ImageContent[]
  final String? streamingBehavior; // "steer" | "followUp"
  final String? sessionPath;
  final String message;
  PromptCommand({required this.message, this.images, this.streamingBehavior, this.sessionPath});
  @override
  String get type => 'prompt';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        if (images != null) 'images': images,
        if (streamingBehavior != null) 'streamingBehavior': streamingBehavior,
        if (sessionPath != null) 'sessionPath': sessionPath,
      };
}
class SteerCommand extends RpcCommand with _GeneratedId {
  final List<Map<String, dynamic>>? images;
  final String? sessionPath;
  final String message;
  SteerCommand({required this.message, this.images, this.sessionPath});
  @override
  String get type => 'steer';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        if (images != null) 'images': images,
        if (sessionPath != null) 'sessionPath': sessionPath,
      };
}
class FollowUpCommand extends RpcCommand with _GeneratedId {
  final List<Map<String, dynamic>>? images;
  final String? sessionPath;
  final String message;
  FollowUpCommand({required this.message, this.images, this.sessionPath});
  @override
  String get type => 'follow_up';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        if (images != null) 'images': images,
        if (sessionPath != null) 'sessionPath': sessionPath,
      };
}
class AbortCommand extends RpcCommand with _GeneratedId {
  final String? sessionPath;
  AbortCommand({this.sessionPath});
  @override
  String get type => 'abort';
  @override
  Map<String, dynamic> toJson() => {'type': type, if (sessionPath != null) 'sessionPath': sessionPath};
}
class ClearQueueCommand extends RpcCommand with _GeneratedId {
  final String? sessionPath;
  ClearQueueCommand({this.sessionPath});
  @override
  String get type => 'clear_queue';
  @override
  Map<String, dynamic> toJson() => {'type': type, if (sessionPath != null) 'sessionPath': sessionPath};
}
class QueueRemoveCommand extends RpcCommand with _GeneratedId {
  final String kind; // "steering" | "followUp"
  final int index;
  final String? sessionPath;
  QueueRemoveCommand({required this.kind, required this.index, this.sessionPath});
  @override
  String get type => 'queue_remove';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'kind': kind,
        'index': index,
        if (sessionPath != null) 'sessionPath': sessionPath,
      };
}
class StopWorkflowRunCommand extends RpcCommand with _GeneratedId {
  final String runId;
  StopWorkflowRunCommand({required this.runId});
  @override
  String get type => 'stop_workflow_run';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'runId': runId};
}
// ─── 4.2 Sessions ───────────────────────────────────────────────
class NewSessionCommand extends RpcCommand with _GeneratedId {
  final String? parentSession;
  final String? cwd;
  NewSessionCommand({this.parentSession, this.cwd});
  @override
  String get type => 'new_session';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (parentSession != null) 'parentSession': parentSession,
        if (cwd != null) 'cwd': cwd,
      };
}
class ClearConversationCommand extends RpcCommand with _GeneratedId {
  ClearConversationCommand();
  @override
  String get type => 'clear_conversation';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class ListSessionsCommand extends RpcCommand with _GeneratedId {
  ListSessionsCommand();
  @override
  String get type => 'list_sessions';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class SwitchSessionCommand extends RpcCommand with _GeneratedId {
  final String sessionPath;
  SwitchSessionCommand({required this.sessionPath});
  @override
  String get type => 'switch_session';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'sessionPath': sessionPath};
}
class SetSessionNameCommand extends RpcCommand with _GeneratedId {
  final String sessionPath;
  final String name;
  SetSessionNameCommand({required this.sessionPath, required this.name});
  @override
  String get type => 'set_session_name';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'sessionPath': sessionPath, 'name': name};
}
class GetSessionsStatusCommand extends RpcCommand with _GeneratedId {
  GetSessionsStatusCommand();
  @override
  String get type => 'get_sessions_status';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class AbortSessionCommand extends RpcCommand with _GeneratedId {
  final String sessionPath;
  AbortSessionCommand({required this.sessionPath});
  @override
  String get type => 'abort_session';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'sessionPath': sessionPath};
}
class ExportHtmlCommand extends RpcCommand with _GeneratedId {
  final String sessionPath;
  ExportHtmlCommand({required this.sessionPath});
  @override
  String get type => 'export_html';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'sessionPath': sessionPath};
}
class ExportJsonlCommand extends RpcCommand with _GeneratedId {
  final String sessionPath;
  ExportJsonlCommand({required this.sessionPath});
  @override
  String get type => 'export_jsonl';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'sessionPath': sessionPath};
}
// ─── 4.3 State & models ─────────────────────────────────────────
class GetStateCommand extends RpcCommand with _GeneratedId {
  GetStateCommand();
  @override
  String get type => 'get_state';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class GetMessagesCommand extends RpcCommand with _GeneratedId {
  GetMessagesCommand();
  @override
  String get type => 'get_messages';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class GetEntriesCommand extends RpcCommand with _GeneratedId {
  GetEntriesCommand();
  @override
  String get type => 'get_entries';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class GetTreeCommand extends RpcCommand with _GeneratedId {
  GetTreeCommand();
  @override
  String get type => 'get_tree';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class SetModelCommand extends RpcCommand with _GeneratedId {
  final String provider;
  final String modelId;
  SetModelCommand({required this.provider, required this.modelId});
  @override
  String get type => 'set_model';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'provider': provider, 'modelId': modelId};
}
class CycleModelCommand extends RpcCommand with _GeneratedId {
  CycleModelCommand();
  @override
  String get type => 'cycle_model';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class GetAvailableModelsCommand extends RpcCommand with _GeneratedId {
  GetAvailableModelsCommand();
  @override
  String get type => 'get_available_models';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class RefreshModelsCommand extends RpcCommand with _GeneratedId {
  RefreshModelsCommand();
  @override
  String get type => 'refresh_models';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class SetThinkingLevelCommand extends RpcCommand with _GeneratedId {
  final String level; // "off"|"minimal"|"low"|"medium"|"high"
  SetThinkingLevelCommand({required this.level});
  @override
  String get type => 'set_thinking_level';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'level': level};
}
class CycleThinkingLevelCommand extends RpcCommand with _GeneratedId {
  CycleThinkingLevelCommand();
  @override
  String get type => 'cycle_thinking_level';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class SetPermissionModeCommand extends RpcCommand with _GeneratedId {
  final String mode; // "default"|"plan"|"auto"
  SetPermissionModeCommand({required this.mode});
  @override
  String get type => 'set_permission_mode';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'mode': mode};
}
class GetPermissionModeCommand extends RpcCommand with _GeneratedId {
  GetPermissionModeCommand();
  @override
  String get type => 'get_permission_mode';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}
class AddSessionAllowRulesCommand extends RpcCommand with _GeneratedId {
  final List<String> rules; // e.g. ["bash(npm test)"]
  AddSessionAllowRulesCommand({required this.rules});
  @override
  String get type => 'add_session_allow_rules';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'rules': rules};
}
class SetPlanModeCommand extends RpcCommand with _GeneratedId {
  final bool enabled;
  SetPlanModeCommand({required this.enabled});
  @override
  String get type => 'set_plan_mode';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'enabled': enabled};
}
class SetSteeringModeCommand extends RpcCommand with _GeneratedId {
  final String mode; // "all" | "one-at-a-time"
  SetSteeringModeCommand({required this.mode});
  @override
  String get type => 'set_steering_mode';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'mode': mode};
}
class SetFollowUpModeCommand extends RpcCommand with _GeneratedId {
  final String mode; // "all" | "one-at-a-time"
  SetFollowUpModeCommand({required this.mode});
  @override
  String get type => 'set_follow_up_mode';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'mode': mode};
}
/// Sent in answer to an extension_ui_request (id matches the request id).
class ExtensionUiResponseCommand extends RpcCommand {
  final String requestId;
  final Map<String, dynamic> data;
  ExtensionUiResponseCommand({required this.requestId, this.data = const {}});
  @override
  String get type => 'extension_ui_response';
  // The request id IS the correlation id here (doc 03 §4.5).
  @override
  String get id => requestId;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'id': id, ...data};
}