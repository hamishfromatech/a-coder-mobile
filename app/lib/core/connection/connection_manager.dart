// lib/core/connection/connection_manager.dart
library;
/// Connection manager — orchestrates RpcClient with exponential backoff,
/// ping policy, and post-reconnect resync (doc 02 §7.1).
import 'dart:async';
import 'dart:math';
import '../protocol/events.dart';
import 'connection_state.dart';
import 'rpc_client.dart';
/// Backoff sequence: 1s → 2s → 4s → 8s → 15s (cap), with ±20% jitter.
const _backoffBaseMs = [1000, 2000, 4000, 8000, 15000];
final _random = Random();
class ConnectionManager {
  final RpcClient client;
  final String hostUrl; // ws:// or wss:// URL for this host
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _isConnected = false;
  bool _shuttingDown = false;
  bool _terminalAuthFailure = false;
  Future<void>? _connectFuture;
  Future<void>? _resyncFuture;
  late StreamSubscription<ConnectionInfo> _stateSub;
  /// Connection info stream (for UI).
  Stream<ConnectionInfo> get stateStream => _stateController.stream;
  final _stateController = StreamController<ConnectionInfo>.broadcast();
  /// Current connection info.
  ConnectionInfo get currentState => _currentState;
  ConnectionInfo _currentState = const ConnectionInfo();
  /// Event listener for protocol events (set by the app).
  late void Function(String eventType, Map<String, dynamic> data) onEvent;
  /// Bridge frame handler.
  late void Function(BridgeControlFrame frame) onBridgeFrame;
  /// Error logger.
  late void Function(String message) onError;
  ConnectionManager({required this.client, required this.hostUrl}) {
    client.listener = _RpcClientBridge(this);
    _stateSub = client.stateStream.listen(_handleClientStateChange);
  }
  /// Start connecting (called from UI after pairing).
  Future<void> connect() async {
    _shuttingDown = false;
    _terminalAuthFailure = false;
    _attempt = 0;
    await _connectClient();
  }

  Future<void> connectClient() => _connectClient();
  void scheduleReconnect(int ms) => _scheduleReconnect(ms);
  Future<void> handleClientStateChange(ConnectionInfo info) => _handleClientStateChange(info);

  Future<void> _connectClient() async {
    if (_connectFuture != null) {
      await _connectFuture;
      return;
    }
    final future = _doConnect();
    _connectFuture = future;
    try {
      await future;
    } finally {
      _connectFuture = null;
    }
  }
  Future<void> _doConnect() async {
    try {
      await client.connect();
    } catch (e) {
      onError('Connect failed: $e');
    }
  }
  /// Stop and disconnect.
  Future<void> disconnect() async {
    _shuttingDown = true;
    _cancelReconnectTimer();
    await client.disconnect();
  }
  /// Force reconnect immediately (called on app resume, network change).
  /// No-op while the connection is healthy — tearing down a working
  /// connection just to rebuild it drops in-flight turn state.
  void forceReconnectNow() {
    if (_shuttingDown || _terminalAuthFailure) return;
    if (_currentState.state == ConnectionState.ready || _isConnected) return;
    if (_connectFuture != null || _reconnectTimer != null) return; // dedupe
    _attempt = 0; // reset backoff
    _scheduleReconnect(0);
  }
  /// Dedup entry points for app-lifecycle / connectivity events.
  void onAppResumed() => forceReconnectNow();
  void onConnectivityChanged() => forceReconnectNow();
  /// Handle a bridge control frame from the engine.
  void handleBridgeFrame(BridgeControlFrame frame) {
    switch (frame.event) {
      case 'connected':
        break;
      case 'shutting_down':
        _changeState(const ConnectionInfo(state: ConnectionState.shuttingDown));
        _shuttingDown = true;
        disconnect();
        break;
      case 'engine_exited':
        onError('Engine exited (code ${frame.code}) — restarting...');
        break;
      case 'slow_client':
        onError('Network too slow — server may drop this connection');
        break;
      case 'engine_failed':
        _changeState(ConnectionInfo(
          state: ConnectionState.disconnected,
          errorMessage: 'Engine failed after ${frame.attempts} restart attempts',
        ));
        onError('Engine failed — check desktop app');
        break;
      case 'server_version':
        _attempt = 0;
        _isConnected = true;
        unawaited(_resync());
        break;
      default:
        onError('Unknown bridge frame: ${frame.event}');
    }
  }
  /// Handle protocol events from the engine.
  void handleEvent(String eventType, Map<String, dynamic> data) {
    onEvent(eventType, data);
  }
  // ─── Reconnection logic ──────────────────────────────────────
  Future<void> _handleClientStateChange(ConnectionInfo info) async {
    switch (info.state) {
      case ConnectionState.connecting:
        _changeState(info);
        break;
      case ConnectionState.authenticating:
        _changeState(info);
        break;
      case ConnectionState.ready:
        if (!_isConnected) {
          _isConnected = true;
          _attempt = 0;
          await _resync();
        }
        _changeState(info);
        break;
      case ConnectionState.reconnecting:
        _changeState(info);
        break;
      case ConnectionState.disconnected:
        _isConnected = false;
        if (info.errorMessage != null && _isAuthError(info.errorMessage!)) {
          _terminalAuthFailure = true;
          _cancelReconnectTimer();
          _changeState(ConnectionInfo(
            state: ConnectionState.disconnected,
            errorMessage: info.errorMessage,
          ));
          onError(info.errorMessage ?? 'Auth failed');
          return;
        }
        if (!_shuttingDown) {
          final delay = Duration(milliseconds: backoffMs(_attempt));
          _changeState(ConnectionInfo(
            state: ConnectionState.reconnecting,
            reconnectAttempt: _attempt + 1,
            nextRetryIn: delay,
            errorMessage: info.errorMessage,
          ));
          _scheduleReconnect(delay.inMilliseconds);
        } else {
          _changeState(info);
        }
        break;
      case ConnectionState.shuttingDown:
        _changeState(info);
        break;
    }
  }
  bool _isAuthError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('authentication') ||
        lower.contains('auth failed');
  }
  void _scheduleReconnect(int ms) {
    if (_shuttingDown || _terminalAuthFailure) return;
    if (_reconnectTimer != null) {
      _reconnectTimer?.cancel();
    }
    _reconnectTimer = Timer(Duration(milliseconds: ms), () {
      _reconnectTimer = null;
      if (_shuttingDown || _terminalAuthFailure) return;
      _attempt++;
      unawaited(_connectClient());
    });
  }
  /// Public backoff calculation (base index clamped; ±20% jitter).
  int backoffMs(int attempt) => _backoffMs(attempt);
  int _backoffMs(int attempt) {
    final baseIdx = attempt.clamp(0, _backoffBaseMs.length - 1);
    final base = _backoffBaseMs[baseIdx];
    final roll = _random.nextDouble();
    return (base * (0.8 + 0.4 * roll)).round();
  }
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  // ─── Resync after reconnect ──────────────────────────────────
  /// Public resync entry point (connection + tests).
  Future<void> resync() => _resync();
  Future<void> _resync() async {
    if (_resyncFuture != null) return _resyncFuture;
    final future = _doResync();
    _resyncFuture = future;
    try {
      await future;
    } finally {
      _resyncFuture = null;
    }
  }
  Future<void> _doResync() async {
    try {
      _changeState(_currentState.copyWith(isResyncing: true, errorMessage: 'Reconnected — resyncing'));
      // Step 1: get_state for current session state
      await client.sendCommand('get_state', {});
      // Step 2: get_messages to refresh transcript. Server may return
      // FEWER messages than local (session truncated/switched) — state
      // layer replaces the list wholesale on response, dropping the tail.
      await client.sendCommand('get_messages', {});
      // Step 3: get_sessions_status for background sessions
      await client.sendCommand('get_sessions_status', {});
      if (!_shuttingDown) {
        _changeState(const ConnectionInfo(
          state: ConnectionState.ready,
          isResyncing: false,
        ));
      }
    } catch (e) {
      onError('Resync failed: $e');
      _changeState(_currentState.copyWith(isResyncing: false, errorMessage: 'Resync failed: $e'));
      // The socket may still be alive but our state is stale — force a
      // clean reconnect cycle instead of waiting for a ping timeout.
      if (!_shuttingDown && !_terminalAuthFailure) {
        _scheduleReconnect(0);
      }
    }
  }
  void _changeState(ConnectionInfo info) {
    _currentState = info;
    if (!_stateController.isClosed) _stateController.add(info);
  }
  /// Clean up resources.
  void dispose() {
    _cancelReconnectTimer();
    _stateSub.cancel();
    if (!_stateController.isClosed) _stateController.close();
  }
}
/// Bridge that wires RpcClient events to ConnectionManager.
class _RpcClientBridge implements RpcClientListener {
  final ConnectionManager manager;
  const _RpcClientBridge(this.manager);
  @override void onEvent(String eventType, Map<String, dynamic> data) => manager.handleEvent(eventType, data);
  @override void onBridgeFrame(BridgeControlFrame frame) => manager.handleBridgeFrame(frame);
  @override void onConnectionStateChange(ConnectionInfo info) {} // handled by ConnectionManager itself
  @override void onError(String message) => manager.onError(message);
}
