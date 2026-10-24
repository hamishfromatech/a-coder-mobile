// lib/core/connection/rpc_client.dart
library;
/// RPC client — WebSocket connection manager with:
/// - id correlation (UUID v4 per command)
/// - per-command timeouts (15s default, 60s for get_messages/export_*)
/// - send queue (enqueue while ready; disable composer when disconnected)
/// - ping policy (get_state ping every 30s of inactivity)
import 'dart:async';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../protocol/wire.dart' as wire;
import '../protocol/events.dart';
import 'connection_state.dart';
const _uuid = Uuid();
/// Error returned when the engine answers success:false.
class CommandError implements Exception {
  final String message;
  final String? id;
  const CommandError(this.message, {this.id});
  @override
  String toString() => 'CommandError($message${id != null ? ', id: $id' : ''})';
}
/// Pending command waiting for a response.
class PendingCommand {
  final String id;
  late final Timer timer;
  final Completer<Map<String, dynamic>> completer;
  final Duration timeout;
  PendingCommand({required this.id, required this.timeout})
      : completer = Completer<Map<String, dynamic>>() {
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout after ${timeout.inSeconds}s for command $id');
      }
    });
  }
  void cancel() {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.completeError('Cancelled');
    }
  }
}
/// Typed response handler. Maps command type → response parsing.
typedef ResponseHandler = Future<void> Function(Map<String, dynamic> data);
abstract class RpcClientListener {
  /// Called when an event arrives from the engine (not a response).
  void onEvent(String eventType, Map<String, dynamic> data);
  /// Called when a bridge control frame arrives.
  void onBridgeFrame(BridgeControlFrame frame);
  /// Called when connection state changes.
  void onConnectionStateChange(ConnectionInfo info);
  /// Called for errors (logged + surfaced to UI).
  void onError(String message);
}
class RpcClient {
  final String wsUrl;
  final String? token; // Bearer token sent on the WS upgrade handshake
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, PendingCommand> _pending = {};
  final Map<String, ResponseHandler> _responseHandlers = {};
  Timer? _pingTimer;
  DateTime? _lastInboundTime;
  bool _isConnected = false;
  ConnectionInfo _connectionState = const ConnectionInfo();
  RpcClientListener? _listener;
  /// Current connection info (streamed via a BroadcastStream).
  Stream<ConnectionInfo> get stateStream => _stateController.stream;
  final _stateController = StreamController<ConnectionInfo>.broadcast();
  /// Set the listener before connecting.
  set listener(RpcClientListener value) {
    _listener = value;
  }
  RpcClient({required this.wsUrl, this.token});
  /// Open connection, authenticate, and start receiving events.
  Future<void> connect() async {
    if (_isConnected ||
        _connectionState.state == ConnectionState.connecting ||
        _connectionState.state == ConnectionState.authenticating) {
      return; // already open or a handshake is in flight
    }
    _changeState(const ConnectionInfo(state: ConnectionState.connecting));
    try {
      // Bearer token rides the upgrade handshake headers (doc 04 §4).
      final headers = <String, dynamic>{
        if (token != null) 'Authorization': 'Bearer $token',
      };
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl), headers: headers);
      final channel = _channel!;
      await channel.ready; // wait for open
      _changeState(const ConnectionInfo(state: ConnectionState.authenticating));
      _isConnected = true;
      _startPingTimer();
      // Set up the message stream
      _subscription = channel.stream.listen(
        _handleInbound,
        onError: _handleError,
        onDone: () {
          if (_isConnected) {
            _listener?.onError('Connection closed');
            _changeState(const ConnectionInfo(state: ConnectionState.disconnected));
            _isConnected = false;
          }
        },
      );
    } catch (e) {
      _isConnected = false;
      _changeState(const ConnectionInfo(state: ConnectionState.disconnected, errorMessage: 'Connection failed'));
      _listener?.onError('Connection failed: $e');
    }
  }
  /// Close the connection cleanly.
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final p in _pending.values) p.cancel();
    _pending.clear();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _changeState(const ConnectionInfo(state: ConnectionState.disconnected));
  }
  /// Send a command and wait for the response. Returns raw JSON data.
  Future<Map<String, dynamic>> sendCommand(String type, Map<String, dynamic> payload, {Duration timeout = const Duration(seconds: 15)}) async {
    final id = _uuid.v4();
    final command = {'type': type, 'id': id, ...payload};
    // Set a longer timeout for slow commands
    if (type == 'get_messages' || type.startsWith('export_')) {
      timeout = const Duration(seconds: 60);
    }
    final pending = PendingCommand(id: id, timeout: timeout);
    _pending[id] = pending;
    try {
      _channel?.sink.add(wire.serializeLine(command));
      return await pending.completer.future;
    } catch (e) {
      rethrow;
    } finally {
      _pending.remove(id);
    }
  }
  /// Send a command without waiting for response (fire-and-forget).
  void sendEvent(String type, Map<String, dynamic> payload) {
    final id = _uuid.v4();
    final command = {'type': type, 'id': id, ...payload};
    if (_isConnected) {
      _channel?.sink.add(wire.serializeLine(command));
    } else {
      _listener?.onError('Dropped fire-and-forget $type — not connected');
    }
  }

  /// Send a fully-formed wire line verbatim (caller owns the id).
  /// Used where the correlation id must NOT be freshly generated — e.g.
  /// extension_ui_response, which must echo the REQUEST id (doc 03 §4.5).
  void sendRaw(String line) {
    if (_isConnected) {
      _channel?.sink.add(line.endsWith('\n') ? line : '$line\n');
    } else {
      _listener?.onError('Dropped raw send — not connected');
    }
  }
  /// Register a one-shot handler for a specific response type.
  void onResponse(String commandType, ResponseHandler handler) {
    _responseHandlers[commandType] = handler;
  }
  // ─── Inbound processing ──────────────────────────────────────
  Future<void> _handleInbound(dynamic data) async {
    final str = data is String ? data : data.toString();
    if (str.isEmpty) return;
    // Update last inbound time for ping logic
    _lastInboundTime = DateTime.now();
    // Parse the line
    final obj = wire.parseLine(str);
    if (obj == null || obj is! Map<String, dynamic>) return;
    // Check for bridge control frames first
    if (obj['type'] == 'bridge') {
      try {
        final frame = BridgeControlFrame.fromJson(obj);
        _listener?.onBridgeFrame(frame);
        return;
      } catch (_) {}
    }
    // Check for response (has `id` field and `success`)
    if (obj['id'] != null && obj['type'] == 'response') {
      await _handleResponse(obj);
      return;
    }
    // Otherwise it's an event — dispatch to listener
    final eventType = obj['type'] as String?;
    if (eventType != null) {
      _listener?.onEvent(eventType, obj);
    }
  }
  Future<void> _handleResponse(Map<String, dynamic> json) async {
    final id = json['id'] as String?;
    if (id == null) return;
    final pending = _pending[id];
    // Check response handlers first (for specific command responses)
    final responseType = json['command'] as String?;
    final handler = responseType != null ? _responseHandlers[responseType] : null;
    if (handler != null) {
      try {
        await handler(json);
      } catch (e) {
        // A bad handler must never block the pending command's completer —
        // that would time out the whole command (and abort resyncs).
        _listener?.onError('Response handler error ($responseType): $e');
      }
    }
    if (pending != null) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        final success = json['success'] as bool? ?? false;
        if (!success) {
          // Surface engine errors to the awaiting caller.
          pending.completer.completeError(
            CommandError(json['error'] as String? ?? 'unknown error', id: id),
          );
        } else {
          final data = json['data'] as Map<String, dynamic>? ?? {};
          pending.completer.complete(data);
        }
      }
    }
    // Unknown/late response — drop (same as desktop client.rs)
  }
  // ─── Ping / inactivity ───────────────────────────────────────
  /// Consecutive unanswered pings. 2 in a row → force reconnect
  /// (doc 05 §5: "2 missed pings → reconnect") — catches half-open TCP
  /// connections where the socket looks alive but the peer is gone.
  int _missedPings = 0;

  void _startPingTimer() {
    _lastInboundTime = DateTime.now();
    _missedPings = 0;
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final lastInbound = _lastInboundTime;
      if (lastInbound != null && DateTime.now().difference(lastInbound) > const Duration(seconds: 30)) {
        // No inbound for 30s → send lightweight ping
        _sendPing();
      }
    });
  }

  void _sendPing() async {
    try {
      // Short timeout so a dead connection is detected on the next tick,
      // not a full command-timeout later.
      await sendCommand('get_state', {}, timeout: const Duration(seconds: 10));
      _missedPings = 0;
    } catch (_) {
      _missedPings++;
      if (_missedPings >= 2) {
        _missedPings = 0;
        _listener?.onError('2 missed pings — connection appears dead, reconnecting');
        // Drop the socket so the normal disconnect→reconnect flow kicks in.
        await disconnect();
      }
    }
  }
  // ─── Error handling ──────────────────────────────────────────
  void _handleError(Object error, StackTrace stack) {
    _listener?.onError('Connection error: $error');
  }
  /// Change connection state and notify listeners.
  void _changeState(ConnectionInfo info) {
    final prev = _connectionState;
    final changed = prev.state != info.state ||
        prev.reconnectAttempt != info.reconnectAttempt ||
        prev.isResyncing != info.isResyncing ||
        prev.errorMessage != info.errorMessage ||
        prev.nextRetryIn != info.nextRetryIn;
    if (changed) {
      _connectionState = info;
      _stateController.add(info);
      _listener?.onConnectionStateChange(info);
    }
  }
  /// Clean up resources.
  void dispose() {
    _subscription?.cancel();
    _pingTimer?.cancel();
    for (final p in _pending.values) p.cancel();
    _stateController.close();
  }
}