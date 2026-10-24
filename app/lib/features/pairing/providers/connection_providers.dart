// lib/features/pairing/providers/connection_providers.dart
library;
/// Active-host + session-connection providers (doc 05 §4, M3 wiring).
///
/// `sessionControllerProvider` owns the full stack for the active paired
/// host: RpcClient → ConnectionManager → event router → chat state. Screens
/// watch it for connection status and call it for every command.

import 'dart:async';
import 'dart:convert' show jsonEncode;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connection/connection_manager.dart';
import '../../../core/connection/connection_state.dart';
import '../../../core/connection/host_registry.dart';
import '../../../core/connection/rpc_client.dart';
import '../../../core/protocol/events.dart' as proto;
import '../../../core/protocol/responses.dart' as responses;
import '../../chat/providers/chat_providers.dart';
import '../../chat/providers/event_router.dart' as er;
import '../../sessions/providers/sessions_providers.dart';

// ─── Active host ──────────────────────────────────────────────────

/// The persisted active-host id (invalidated after pairing / forget).
final activeHostIdProvider = FutureProvider<String?>((ref) {
  return HostRegistry().getActiveHostId();
});

/// The active PairedHost, resolved from the registry.
final activeHostProvider = FutureProvider<PairedHost?>((ref) async {
  final id = await ref.watch(activeHostIdProvider.future);
  if (id == null) return null;
  return HostRegistry().getHost(id);
});

// ─── Session controller ───────────────────────────────────────────

/// UI-facing projection of the session controller's state. Screens (the cold-
/// boot splash in particular) watch this so they can be tested with plain
/// provider overrides instead of a live connection stack.
final connectionStateProvider =
    Provider.autoDispose.family<SessionControllerState, String>((ref, hostId) {
  return ref.watch(sessionControllerProvider(hostId));
});

/// Connection + load status for the active host.
class SessionControllerState {
  final ConnectionInfo connection;
  /// True during the initial connect → resync sequence.
  final bool starting;
  const SessionControllerState({
    this.connection = const ConnectionInfo(),
    this.starting = false,
  });

  bool get isReady => connection.state == ConnectionState.ready && !starting;

  SessionControllerState copyWith({ConnectionInfo? connection, bool? starting}) =>
      SessionControllerState(connection: connection ?? this.connection, starting: starting ?? this.starting);
}

final sessionControllerProvider = StateNotifierProvider.autoDispose
    .family<SessionController, SessionControllerState, String>((ref, hostId) {
  final controller = SessionController(ref, hostId);
  ref.onDispose(controller.dispose);
  unawaited(controller.start());
  return controller;
});

class SessionController extends StateNotifier<SessionControllerState> {
  final Ref _ref;
  final String hostId;
  PairedHost? _host;
  RpcClient? _client;
  ConnectionManager? _manager;
  StreamSubscription<ConnectionInfo>? _connSub;
  bool _disposed = false;
  /// Prompts composed while disconnected — flushed in order on ready (doc 05 §5:
  /// "buffered-unsent while offline").
  final List<({String mode, String text, List<Map<String, dynamic>> images})> _outbox = [];

  SessionController(this._ref, this.hostId) : super(const SessionControllerState(starting: true));

  /// Load host metadata + token, build the stack, and connect.
  /// The ConnectionManager drives the full sequence: connect → auth →
  /// server_version → resync (get_state/get_messages/get_sessions_status),
  /// whose responses flow into the handlers registered here.
  Future<void> start() async {
    final host = await HostRegistry().getHost(hostId);
    if (host == null) {
      if (!_disposed) {
        state = const SessionControllerState(
          connection: ConnectionInfo(state: ConnectionState.disconnected, errorMessage: 'Host not found — re-pair this machine'),
          starting: false,
        );
      }
      return;
    }
    _host = host;
    final token = await HostRegistry().getToken(hostId);
    final client = RpcClient(wsUrl: host.wsUrl, token: token);
    final manager = ConnectionManager(client: client, hostUrl: host.wsUrl);

    manager.onEvent = _onEvent;
    manager.onError = (msg) => debugPrint('[session:$hostId] $msg');
    _registerResponseHandlers(client);

    _client = client;
    _manager = manager;
    _connSub = manager.stateStream.listen(_onConnState);
    await manager.connect();
  }

  void _onConnState(ConnectionInfo info) {
    if (_disposed) return;
    state = state.copyWith(connection: info);
    // Connected + resynced → deliver anything buffered while offline.
    if (info.state == ConnectionState.ready && !info.isResyncing && _outbox.isNotEmpty) {
      _flushOutbox();
    }
  }

  bool get _isReady => state.connection.state == ConnectionState.ready;

  Future<void> _flushOutbox() async {
    while (_outbox.isNotEmpty && _isReady && !_disposed) {
      final item = _outbox.first;
      try {
        await _sendPromptNow(item.text, mode: item.mode, images: item.images);
        _outbox.removeAt(0);
      } catch (_) {
        break; // connection dropped mid-flush — retry on next ready
      }
    }
  }

  // ─── Inbound wiring ────────────────────────────────────────────

  void _onEvent(String eventType, Map<String, dynamic> data) {
    if (_disposed) return;
    if (eventType == 'session_start') {
      // Desktop App.tsx session_start: the engine switched sessions — clear
      // local state and resync so the UI matches the authoritative session
      // (a desktop-side switch is mirrored on the phone in real time).
      _ref.read(chatStateProvider.notifier).reset();
      _ref.read(subagentsProvider.notifier).clear();
      _ref.read(sessionStatsProvider.notifier).clear();
      _ref.read(slashCommandsProvider.notifier).clear();
      unawaited(_resyncAfterSessionStart());
      return;
    }
    if (eventType == 'subagents_update') {
      final agents = (data['agents'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(proto.SubAgentRecord.fromJson)
          .toList();
      _ref.read(subagentsProvider.notifier).update(agents);
      return;
    }
    if (eventType == 'background_processes_update') {
      final processes = (data['processes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _ref.read(backgroundProcessesProvider.notifier).update(processes);
      return;
    }
    if (eventType == 'sessions_update') {
      // Background session runtime statuses — separate provider (doc 05 §4).
      final list = (data['sessions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(proto.RuntimeSessionStatus.fromJson)
          .toList();
      _ref.read(backgroundSessionsProvider.notifier).update(list);
      return;
    }
    // All other events flow through the pure router into chat state.
    _ref.read(chatStateProvider.notifier).applyEvent(eventType, data);
  }

  void _registerResponseHandlers(RpcClient client) {
    void guarded(String type, Future<void> Function(Map<String, dynamic> data) handler) {
      client.onResponse(type, (json) async {
        try {
          await handler(json['data'] as Map<String, dynamic>? ?? {});
        } catch (e) {
          debugPrint('[session:$hostId] $type handler error: $e');
        }
      });
    }

    guarded('get_state', (data) async {
      final resp = responses.SessionStateResponse.fromJson(data);
      _ref.read(chatStateProvider.notifier).updateFromStateResponse(resp);
    });

    guarded('get_session_stats', (data) async {
      _ref.read(sessionStatsProvider.notifier).updateFromResponse(data);
    });

    guarded('get_commands', (data) async {
      final commands = (data['commands'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _ref.read(slashCommandsProvider.notifier).update(commands);
    });

    guarded('get_messages', (data) async {
      final resp = responses.GetMessagesResponse.fromJson(data);
      _ref.read(chatStateProvider.notifier).loadMessages(resp.messages);
    });

    guarded('get_transcript_page', (data) async {
      final resp = responses.TranscriptPageResponse.fromJson(data);
      _ref.read(chatStateProvider.notifier).loadTranscriptPage(resp);
    });

    guarded('get_sessions_status', (data) async {
      final list = (data['sessions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(proto.RuntimeSessionStatus.fromJson)
          .toList();
      _ref.read(backgroundSessionsProvider.notifier).update(list);
    });

    guarded('list_sessions', (data) async {
      final resp = responses.ListSessionsResponse.fromJson(data);
      _ref.read(sessionsListProvider.notifier).replaceAll(resp.sessions);
    });
  }

  // ─── Commands ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> _send(String type, Map<String, dynamic> payload, {Duration? timeout}) async {
    final client = _client;
    if (client == null) throw Exception('Not connected');
    final result = await client.sendCommand(type, payload,
        timeout: timeout ?? const Duration(seconds: 15));
    // The engine accepted a command — drop a transient "engine starting" banner.
    if (state.connection.errorMessage == engineStartingMessage) {
      state = state.copyWith(connection: state.connection.copyWith(errorMessage: null));
    }
    return result;
  }

  /// Send the composer text. mode: prompt | steer | followUp.
  /// While disconnected the message is buffered and flushed on reconnect.
  Future<void> sendPrompt(String text, {String mode = 'prompt', List<Map<String, dynamic>> images = const []}) async {
    if (text.trim().isEmpty) return;
    if (!_isReady) {
      _outbox.add((mode: mode, text: text, images: images));
      _ref.read(chatStateProvider.notifier).addLocalUserMessage(text);
      return;
    }
    await _sendPromptNow(text, mode: mode, images: images);
  }

  Future<void> _sendPromptNow(String text, {String mode = 'prompt', List<Map<String, dynamic>> images = const []}) async {
    switch (mode) {
      case 'steer':
        await _send('steer', {'message': text, if (images.isNotEmpty) 'images': images});
      case 'followUp':
        await _send('follow_up', {'message': text, if (images.isNotEmpty) 'images': images});
      default:
        await _send('prompt', {'message': text, if (images.isNotEmpty) 'images': images});
    }
    // Optimistic echo — the engine may not replay the user message.
    _ref.read(chatStateProvider.notifier).addLocalUserMessage(text);
  }

  Future<void> abort() => _send('abort', {});

  /// Abort a session by path (works for background sessions too).
  Future<void> abortSession(String sessionPath) =>
      _send('abort_session', {'sessionPath': sessionPath});

  /// Restore tracked files to a previous turn (file-history rewind).
  /// Returns the engine payload: {steps, filesChanged, insertions, deletions}.
  Future<Map<String, dynamic>> rewindFiles({int steps = 1}) =>
      _send('rewind', {'steps': steps});

  // ─── Extension UI responses (doc 03 §4.5) ──────────────────────
  // Shapes per method:
  //   confirm  → {confirmed: bool}
  //   select   → {value: string}
  //   question → {answers: Record<header, answer>}
  //   input/editor → {value: string}
  //   cancel   → {cancelled: true}
  // extension_ui_response must carry the REQUEST id as its correlation id —
  // not a freshly generated uuid — so responses go through sendRaw.

  /// Permission approval. action: allow | deny | always_allow.
  /// `always_allow` first adds a session allow-rule, then confirms.
  Future<void> respondApproval(er.UiRequest request, String action) async {
    if (action == 'always_allow') {
      // Desktop ToolApprovalBar: run_workflow grants `run_workflow(<name>)`;
      // other tools derive `Tool(subject)` from what the request carries.
      final rule = request.toolName == 'run_workflow' && request.workflowName != null
          ? 'run_workflow(${request.workflowName})'
          : (request.toolName == 'run_workflow'
              ? ''
              : _toolRule(request.toolName, request.message));
      if (rule.isNotEmpty) {
        await _send('add_session_allow_rules', {'rules': [rule]});
      }
    }
    await _respond(request.id, {'confirmed': action != 'deny'});
  }

  /// select (single or multi) → {value: string}.
  Future<void> respondSelect(er.UiRequest request, List<String> selectedLabels) async {
    await _respond(request.id, {'value': selectedLabels.join(',')});
  }

  /// question → `{answers: Record<header, answer>}`. The question header is
  /// carried in the request title (v1: one question per request).
  Future<void> respondQuestion(er.UiRequest request, String answerLabel) async {
    await _respond(request.id, {'answers': {request.title ?? 'question': answerLabel}});
  }

  /// input / editor → {value: string}.
  Future<void> respondInput(er.UiRequest request, String value) async {
    await _respond(request.id, {'value': value});
  }

  /// Dismiss without answering — the engine resolves by its default/timeout.
  Future<void> cancelUiRequest(er.UiRequest request) => _respond(request.id, {'cancelled': true});

  Future<void> _respond(String requestId, Map<String, dynamic> payload) async {
    _client?.sendRaw(wireExtensionUiResponse(requestId, payload));
    _ref.read(chatStateProvider.notifier).removeApproval(requestId);
  }

  /// Desktop parity: set_model takes provider + modelId separately.
  Future<void> setModel(String provider, String modelId) =>
      _send('set_model', {'provider': provider, 'modelId': modelId});
  Future<void> setThinkingLevel(String level) => _send('set_thinking_level', {'level': level});
  Future<void> setPermissionMode(String mode) => _send('set_permission_mode', {'mode': mode});

  Future<void> newSession() async {
    await _send('new_session', {});
    _ref.read(chatStateProvider.notifier).reset();
    await reload();
  }

  Future<void> switchSession(String sessionPath) async {
    await _send('switch_session', {'sessionPath': sessionPath});
    _ref.read(chatStateProvider.notifier).reset();
    await reload();
  }

  /// Desktop Esc-to-dequeue parity: clear the queue and return the removed
  /// items so the composer can restore them.
  Future<({List<String> steering, List<String> followUp})> clearQueue() async {
    final data = await _send('clear_queue', {});
    return (
      steering: (data['steering'] as List<dynamic>? ?? []).whereType<String>().toList(),
      followUp: (data['followUp'] as List<dynamic>? ?? []).whereType<String>().toList(),
    );
  }

  Future<void> removeQueueItem(String kind, int index) =>
      _send('queue_remove', {'kind': kind, 'index': index});

  Future<void> renameSession(String sessionPath, String name) =>
      _send('set_session_name', {'sessionPath': sessionPath, 'name': name});

  Future<void> compact() => _send('compact', {}, timeout: const Duration(seconds: 60));

  /// Returns the export URL/path from the engine, or throws.
  Future<String?> exportHtml(String sessionPath) async {
    final data = await _send('export_html', {'sessionPath': sessionPath}, timeout: const Duration(seconds: 60));
    return data['path'] as String? ?? data['url'] as String?;
  }

  Future<List<Map<String, dynamic>>> getAvailableModels() async {
    final data = await _send('get_available_models', {});
    return (data['models'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
  }

  /// Desktop parity: the picker's refresh re-reads models.json + dynamic models.
  Future<void> refreshModels() => _send('refresh_models', {});

  /// Refresh the session list (home screen pull-to-refresh).
  Future<void> refreshSessions() => _send('list_sessions', {});

  /// Page size for the initial transcript load and each "older" request.
  static const int transcriptPageSize = 80;

  /// Scroll-up paging: fetch the page immediately before the oldest loaded
  /// entry and prepend it. No-op while a page is loading or history is done.
  Future<void> loadOlderMessages() async {
    final chat = _ref.read(chatStateProvider);
    final cursor = chat.olderCursor;
    if (!chat.hasMoreBefore || chat.isLoadingOlder || cursor == null) return;
    _ref.read(chatStateProvider.notifier).setLoadingOlder(true);
    try {
      await _send('get_transcript_page', {
        'limit': transcriptPageSize,
        'before': cursor,
      });
    } catch (e) {
      _ref.read(chatStateProvider.notifier).setLoadingOlder(false);
      debugPrint('[session:$hostId] loadOlder failed: $e');
    }
  }

  /// Re-fetch the current session snapshot (chat pull-to-refresh / post-switch).
  /// Desktop parity: state → stats → messages, plus slash commands (App.tsx
  /// connectEngine sequence).
  Future<void> reload() async {
    await _send('get_state', {});
    // Stats are best-effort (context-usage chip).
    try {
      await _send('get_session_stats', {});
    } catch (_) {}
    await _send(
      'get_transcript_page',
      {'limit': transcriptPageSize},
      timeout: const Duration(seconds: 60),
    );
    // Slash commands for composer autocomplete (best-effort).
    try {
      await _send('get_commands', {});
    } catch (_) {}
    await _send('get_sessions_status', {});
  }

  /// session_start: the engine switched/resumed a session — resync without
  /// another switch (the engine already did it).
  Future<void> _resyncAfterSessionStart() async {
    try {
      await reload();
    } catch (e) {
      debugPrint('[session:$hostId] session_start resync failed: $e');
    }
  }

  /// App resume / network change — guarded no-op when healthy.
  void forceReconnectNow() => _manager?.forceReconnectNow();

  PairedHost? get host => _host;

  @override
  void dispose() {
    _disposed = true;
    _connSub?.cancel();
    _manager?.dispose();
    _client?.dispose();
    super.dispose();
  }
}

/// Desktop derives "Tool(subject)" rules from full request metadata; v1
/// approximates with what the request carries.
String _toolRule(String? tool, String? subject) {
  if (tool == null || tool.isEmpty) return '';
  return subject != null && subject.isNotEmpty ? '$tool($subject)' : tool;
}

/// Serialize an extension_ui_response line (request id as correlation id,
/// payload per doc 03 §4.5).
String wireExtensionUiResponse(String requestId, Map<String, dynamic> payload) {
  return '{"type":"extension_ui_response","id":"$requestId"${payload.isEmpty ? '' : ',${_jsonBody(payload)}'}}\n';
}

String _jsonBody(Map<String, dynamic> payload) {
  return payload.entries.map((e) => '"${e.key}":${jsonEncode(e.value)}').join(',');
}
