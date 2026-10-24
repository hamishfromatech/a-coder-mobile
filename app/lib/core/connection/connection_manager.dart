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
    await client.connect();
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
    if (_currentState.state == ConnectionState.ready || _isConnected) return;
    _attempt = 0; // reset backoff
    _scheduleReconnect(0);
  }
  /// Handle a bridge control frame from the engine.
  void handleBridgeFrame(BridgeControlFrame frame) {
    switch (frame.event) {
      case 'connected':
        // Client connected to server — handled by state change
        break;
      case 'shutting_down':
        _changeState(const ConnectionInfo(state: ConnectionState.shuttingDown));
        _shuttingDown = true;
        disconnect();
        break;
      case 'engine_exited':
        onError('Engine exited (code ${frame.code}) — restarting...');
        // Engine will auto-restart; we just resync when it's back
        break;
      case 'slow_client':
        // Server warns this client is falling behind (bufferedAmount high).
        // The bridge drops clients that stay slow; surface it so the user
        // understands an imminent reconnect.
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
        // Auth successful + server version received
        _attempt = 0;
        _isConnected = true;
        _resync();
        break;
      default:
        // Unknown bridge event — log it
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
        // Waiting for server_version frame — handled in handleBridgeFrame
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
        if (!_shuttingDown) {
          // Schedule reconnect with exponential backoff. Preserve the
          // client's error detail (e.g. "401 — wrong token") so the UI
          // can explain WHY it is reconnecting.
          final delay = Duration(milliseconds: _backoffMs(_attempt));
          _changeState(ConnectionInfo(
            state: ConnectionState.reconnecting,
            reconnectAttempt: _attempt + 1,
            nextRetryIn: delay,
            errorMessage: info.errorMessage,
          ));
          _scheduleReconnect(delay.inMilliseconds);
        }
        break;
      case ConnectionState.shuttingDown:
        _changeState(info);
        break;
    }
  }
  void _scheduleReconnect(int ms) {
    _cancelReconnectTimer();
    _reconnectTimer = Timer(Duration(milliseconds: ms), () {
      if (_shuttingDown) return;
      _attempt++;
      client.connect();
    });
  }
  int _backoffMs(int attempt) {
    final baseIdx = attempt.clamp(0, _backoffBaseMs.length - 1);
    final base = _backoffBaseMs[baseIdx];
    // ±20% jitter
    final roll = _random.nextDouble();
    return (base * (0.8 + 0.4 * roll)).round();
  }
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  // ─── Resync after reconnect ──────────────────────────────────
  Future<void> _resync() async {
    try {
      _changeState(_currentState.copyWith(isResyncing: true, errorMessage: 'Reconnected — resyncing'));
      // Step 1: get_state for current session state
      await client.sendCommand('get_state', {});
      // (Dispatched via response handlers / event router by the app layer)
      // Step 2: get_messages to refresh transcript
      await client.sendCommand('get_messages', {});
      // Step 3: get_sessions_status for background sessions
      await client.sendCommand('get_sessions_status', {});
      // Diff message list by length; drop tail if server < local (not implemented here, handled by state layer)
      // If server messageCount > local, fetch and replace.
      _changeState(const ConnectionInfo(
        state: ConnectionState.ready,
        isResyncing: false,
      ));
    } catch (e) {
      onError('Resync failed: $e');
      // The socket may still be alive but our state is stale — force a
      // clean reconnect cycle instead of waiting for a ping timeout.
      if (!_shuttingDown) {
        _scheduleReconnect(0);
      }
    } finally {
      
    }
  }
  void _changeState(ConnectionInfo info) {
    _currentState = info;
    _stateController.add(info);
  }
  /// Clean up resources.
  void dispose() {
    _cancelReconnectTimer();
    _stateSub.cancel();
    _stateController.close();
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