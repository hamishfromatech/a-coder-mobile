// lib/core/connection/connection_state.dart
library;

/// Connection state machine (doc 03 §7.1).
/// States: disconnected → connecting → authenticating → ready,
/// with reconnecting (attempt N, backoff) side state.
enum ConnectionState {
  /// No connection attempt in progress.
  disconnected,

  /// Attempting to open the WebSocket.
  connecting,

  /// WS opened; sending auth token, waiting for server_version frame.
  authenticating,

  /// Auth passed + first get_state received. Fully connected.
  ready,

  /// Reconnecting after a disconnect (attempt N, backoff in progress).
  reconnecting,

  /// Server is shutting down gracefully.
  shuttingDown,
}

/// Full connection state with metadata for UI display.
class ConnectionInfo {
  final ConnectionState state;
  final int reconnectAttempt; // 0 when not reconnecting
  final Duration nextRetryIn; // countdown during reconnecting
  final String?
      errorMessage; // human-readable error (e.g., "401 — wrong token")
  final bool isResyncing; // true after reconnect: get_state → get_messages
  const ConnectionInfo({
    this.state = ConnectionState.disconnected,
    this.reconnectAttempt = 0,
    this.nextRetryIn = Duration.zero,
    this.errorMessage,
    this.isResyncing = false,
  });

  /// Sentinel for "keep current value" in copyWith. Passing an explicit
  /// `errorMessage: null` CLEARS the field (needed to drop the error banner
  /// once the connection recovers); omitting the argument preserves it.
  static const Object _unset = Object();

  ConnectionInfo copyWith({
    ConnectionState? state,
    int? reconnectAttempt,
    Duration? nextRetryIn,
    Object? errorMessage = _unset,
    bool? isResyncing,
  }) {
    return ConnectionInfo(
      state: state ?? this.state,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      nextRetryIn: nextRetryIn ?? this.nextRetryIn,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isResyncing: isResyncing ?? this.isResyncing,
    );
  }

  bool get isConnected => state == ConnectionState.ready;
  bool get isDisconnected => state == ConnectionState.disconnected;
  bool get isReconnecting => state == ConnectionState.reconnecting;
}
