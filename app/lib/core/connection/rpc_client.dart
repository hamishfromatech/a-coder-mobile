// lib/core/connection/rpc_client.dart
library;
/// RPC client — WebSocket connection manager with:
/// - id correlation (UUID v4 per command)
/// - per-command timeouts (15s default, 60s for get_messages/export_*)
/// - send queue (enqueue while ready; disable composer when disconnected)
/// - ping policy (get_state ping every 30s of inactivity)
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../protocol/wire.dart' as wire;
import 'cert_pinning.dart';
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
  Timer? timer;
  final Completer<Map<String, dynamic>> completer;
  final Duration timeout;
  PendingCommand({required this.id, required this.timeout})
      : completer = Completer<Map<String, dynamic>>() {
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout after ${timeout.inSeconds}s for command $id');
      }
      timer?.cancel();
    });
  }
  void cancel() {
    timer?.cancel();
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
  final WebSocketChannel Function(Uri uri, {Map<String, dynamic>? headers})? channelFactory;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, PendingCommand> _pending = {};
  final Map<String, ResponseHandler> _responseHandlers = {};
  // Latest id per command type so stale responses (session switch races)
  // can be discarded while still completing the awaiting caller.
  final Map<String, String> _latestIdByCommandType = {};
  Timer? _pingTimer;
  DateTime? _lastInboundTime;
  bool _isConnected = false;
  bool _connecting = false;
  ConnectionInfo _connectionState = const ConnectionInfo();
  RpcClientListener? _listener;
  /// Current connection info (streamed via a BroadcastStream).
  Stream<ConnectionInfo> get stateStream => _stateController.stream;
  final _stateController = StreamController<ConnectionInfo>.broadcast();
  /// Set the listener before connecting.
  set listener(RpcClientListener value) {
    _listener = value;
  }
  /// SHA-256 certificate pin (lowercase hex) used for wss:// bridges with a
  /// self-signed cert. Null = normal system trust (public CA).
  final String? certFingerprint;
  HttpClient? _httpClient;

  RpcClient({
    required this.wsUrl,
    this.token,
    this.channelFactory,
    this.certFingerprint,
  });
  bool get isConnected => _isConnected;
  ConnectionInfo get connectionState => _connectionState;
  /// Open connection, authenticate, and start receiving events.
  Future<void> connect() async {
    if (_isConnected || _connecting) return;
    if (_stateController.isClosed) return;
    _connecting = true;
    _changeState(const ConnectionInfo(state: ConnectionState.connecting));
    try {
      final headers = <String, dynamic>{
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse(wsUrl);
      final factory = channelFactory;
      if (factory != null) {
        _channel = factory(uri, headers: headers);
      } else if (uri.scheme == 'wss' &&
          certFingerprint != null &&
          certFingerprint!.isNotEmpty) {
        final client = HttpClient();
        _httpClient = client;
        // Only invoked when the chain is not publicly trusted (self-signed LAN
        // bridge). A CA-signed cert is already authenticated by the platform.
        client.badCertificateCallback = (cert, host, port) {
          try {
            return matchesPinnedFingerprint(
                fingerprintOfDer(cert.der), certFingerprint!);
          } catch (_) {
            return false;
          }
        };
        _channel = IOWebSocketChannel.connect(uri,
            headers: headers, customClient: client);
      } else {
        _channel = IOWebSocketChannel.connect(uri, headers: headers);
      }
      final channel = _channel!;
      await channel.ready; // wait for open / auth handshake result
      _changeState(const ConnectionInfo(state: ConnectionState.authenticating));
      _isConnected = true;
      _startPingTimer();
      _subscription = channel.stream.listen(
        handleInbound,
        onError: (Object e, StackTrace st) => _handleError(e, st),
        onDone: () {
          if (_isConnected || _connecting) {
            _failAllPending('Connection closed');
            _isConnected = false;
            _listener?.onError('Connection closed');
            _changeState(const ConnectionInfo(state: ConnectionState.disconnected, errorMessage: 'Connection closed'));
          }
        },
      );
    } catch (e) {
      _isConnected = false;
      final msg = e.toString();
      final isAuth = _isAuthError(msg);
      _failAllPending(isAuth ? 'Auth failed' : 'Connection failed');
      _changeState(ConnectionInfo(
        state: ConnectionState.disconnected,
        errorMessage: isAuth ? 'Auth failed: $msg' : 'Connection failed',
      ));
      _listener?.onError(isAuth ? 'Auth failed: $e' : 'Connection failed: $e');
    } finally {
      _connecting = false;
    }
  }
  /// Close the pinned HttpClient (keeps isolate sockets from leaking across
  /// reconnects).
  void _closeHttpClient() {
    try {
      _httpClient?.close(force: true);
    } catch (_) {}
    _httpClient = null;
  }
  /// Close the connection cleanly.
  Future<void> disconnect() async {
    _connecting = false;
    await _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _failAllPending('Disconnected');
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _closeHttpClient();
    _isConnected = false;
    _changeState(const ConnectionInfo(state: ConnectionState.disconnected));
  }
  bool _isAuthError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('authentication');
  }
  /// Send a command and wait for the response. Returns raw JSON data.
  Future<Map<String, dynamic>> sendCommand(String type, Map<String, dynamic> payload, {Duration timeout = const Duration(seconds: 15)}) async {
    // Per-command timeouts (15s default, 60s for get_messages/export_*).
    if (type == 'get_messages' || type.startsWith('export_')) {
      timeout = const Duration(seconds: 60);
    }
    final id = _uuid.v4();
    _latestIdByCommandType[type] = id;
    final command = {'type': type, 'id': id, ...payload};
    final pending = PendingCommand(id: id, timeout: timeout);
    _pending[id] = pending;
    try {
      if (_isConnected) {
        _channel?.sink.add(wire.serializeLine(command));
      } else {
        // Allow enqueued sends to fail fast rather than hang.
        throw StateError('not connected');
      }
      return await pending.completer.future;
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
  Future<void> handleInbound(dynamic data) async {
    final str = data is String ? data : data.toString();
    if (str.trim().isEmpty) return;
    _lastInboundTime = DateTime.now();
    // Support multiple JSONL records in one frame (defensive).
    for (final line in wire.splitLines(str)) {
      final obj = wire.parseLine(line);
      if (obj == null || obj is! Map<String, dynamic>) continue;
      final json = Map<String, dynamic>.from(obj);
      // Bridge control frames first.
      if (json['type'] == 'bridge') {
        try {
          final frame = BridgeControlFrame.fromJson(json);
          _listener?.onBridgeFrame(frame);
        } catch (_) {}
        continue;
      }
      // Responses.
      if (json['type'] == 'response' && json['id'] != null) {
        await handleResponse(json);
        continue;
      }
      // Events.
      final eventType = json['type'] as String?;
      if (eventType != null) {
        _listener?.onEvent(eventType, json);
      }
    }
  }
  Future<void> handleResponse(Map<String, dynamic> json) async {
    final id = json['id'] as String?;
    if (id == null) return;
    final pending = _pending[id];
    final responseType = json['command'] as String?;
    final isLatest = responseType == null || _latestIdByCommandType[responseType] == id;
    // Response handlers (UI side-effects) only fire for the latest request
    // of that command type — stale responses from old sessions are discarded.
    if (isLatest && responseType != null) {
      final handler = _responseHandlers[responseType];
      if (handler != null) {
        try {
          await handler(json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : (json['data'] as Map?)?.cast<String, dynamic>() ?? {});
        } catch (e) {
          _listener?.onError('Response handler error ($responseType): $e');
        }
      }
    }
    if (pending != null) {
      pending.timer?.cancel();
      if (!pending.completer.isCompleted) {
        final success = json['success'] as bool? ?? false;
        if (!success) {
          pending.completer.completeError(
            CommandError(json['error'] as String? ?? 'unknown error', id: id),
          );
        } else {
          final data = json['data'];
          final map = data is Map<String, dynamic>
              ? data
              : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
          pending.completer.complete(map);
        }
      }
    }
    // Unknown/late response — drop (same as desktop client).
  }
  void _failAllPending(String reason) {
    final ids = List<String>.from(_pending.keys);
    for (final id in ids) {
      final p = _pending.remove(id);
      p?.timer?.cancel();
      if (p != null && !p.completer.isCompleted) {
        p.completer.completeError(reason);
      }
    }
  }
  // ─── Ping / inactivity ───────────────────────────────────────
  int _missedPings = 0;

  void _startPingTimer() {
    _lastInboundTime = DateTime.now();
    _missedPings = 0;
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final lastInbound = _lastInboundTime;
      if (lastInbound != null && DateTime.now().difference(lastInbound) > const Duration(seconds: 30)) {
        _sendPing();
      }
    });
  }

  void _sendPing() async {
    try {
      await sendCommand('get_state', {}, timeout: const Duration(seconds: 10));
      _missedPings = 0;
    } catch (_) {
      _missedPings++;
      if (_missedPings >= 2) {
        _missedPings = 0;
        _listener?.onError('2 missed pings — connection appears dead, reconnecting');
        await disconnect();
      }
    }
  }
  // ─── Error handling ──────────────────────────────────────────
  void _handleError(Object error, StackTrace stack) {
    _failAllPending('Connection error: $error');
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
      if (!_stateController.isClosed) _stateController.add(info);
      _listener?.onConnectionStateChange(info);
    }
  }
  /// Clean up resources.
  void dispose() {
    _connecting = false;
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _failAllPending('Disposed');
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    if (!_stateController.isClosed) _stateController.close();
  }
}
