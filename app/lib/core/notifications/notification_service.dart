// Local alerts for the events that need the user's attention.
//
// Scope: while the app process is alive (foreground, or backgrounded with the
// socket still up) the client raises a local notification for approvals, turn
// completions, background sessions that need input, and failing routines.
// True background delivery (app suspended/killed) requires the APNs/FCM relay
// described in plan/11-push-relay-spike.md; this service is its client-side
// counterpart, not a replacement.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/settings/providers/settings_providers.dart';

enum AlertKind { approval, turnFinished, backgroundWaiting, cronFailure }

/// Platform notification surface (injectable so tests can assert the policy).
abstract class AlertPresenter {
  Future<void> initialize(void Function(String? payload) onTap);
  Future<bool> requestPermission();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
}

/// flutter_local_notifications implementation.
class LocalAlertPresenter implements AlertPresenter {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _channelId = 'acoder_alerts';
  static const _channelName = 'A-Coder alerts';
  static const _channelDescription =
      'Approvals, finished turns and failing scheduled tasks';

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    const android = AndroidInitializationSettings('ic_notification');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ));
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}

/// Alert policy: settings gates, foreground suppression, and dedupe.
/// Why a scheduled job's last run should alert, if at all.
enum CronAlert { failed, needsAttention }

/// Decide whether the job's last run warrants an alert.
///
/// Failure and timeout always do. A `needs_user` / `failed` triage verdict also
/// does: the engine records such runs as `ok` even when the agent was blocked
/// (for example by a permission denial) and produced nothing.
CronAlert? cronAlert(String? lastStatus, Map<String, dynamic>? triage) {
  final status = (lastStatus ?? '').toLowerCase();
  if (status == 'error' || status == 'timeout') return CronAlert.failed;
  final outcome = (triage?['outcome'] as String? ?? '').toLowerCase();
  final action = (triage?['recommendedAction'] as String? ?? '').toLowerCase();
  if (outcome == 'needs_user' || outcome == 'failed' || action == 'pause') {
    return CronAlert.needsAttention;
  }
  return null;
}

class NotificationService {
  NotificationService({AlertPresenter? presenter})
      : presenter = presenter ?? LocalAlertPresenter();

  static final NotificationService instance = NotificationService();

  AlertPresenter presenter;

  bool _initialized = false;
  bool appInForeground = true;

  // Settings snapshot (updated by the app from the settings provider).
  bool enabled = false;
  bool approvals = true;
  bool turnFinished = true;
  bool backgroundWaiting = true;
  bool cronFailures = true;
  bool whileForeground = false;

  final Map<String, DateTime> _lastShown = {};
  final Set<String> _approvalRequests = {};

  /// Called when a notification is tapped. Wired by the app to route to chat.
  void Function(String hostId, String? sessionPath)? onOpenSession;

  void configure(AppSettings settings) {
    enabled = settings.notificationsEnabled;
    approvals = settings.alertApprovals;
    turnFinished = settings.alertTurnFinished;
    backgroundWaiting = settings.alertBackgroundWaiting;
    cronFailures = settings.alertCronFailures;
    whileForeground = settings.alertWhileForeground;
  }

  Future<bool> requestPermission() => presenter.requestPermission();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await presenter.initialize(_handleTap);
  }

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is! Map) return;
      final hostId = map['hostId'] as String? ?? '';
      final sessionPath = map['sessionPath'] as String?;
      if (hostId.isNotEmpty) onOpenSession?.call(hostId, sessionPath);
    } catch (_) {
      // Malformed payload: ignore.
    }
  }

  bool _allowed(AlertKind kind) {
    if (!enabled) return false;
    if (appInForeground && !whileForeground) return false;
    return switch (kind) {
      AlertKind.approval => approvals,
      AlertKind.turnFinished => turnFinished,
      AlertKind.backgroundWaiting => backgroundWaiting,
      AlertKind.cronFailure => cronFailures,
    };
  }

  /// Approvals always win: one per request id, no cooldown.
  Future<void> notifyApproval({
    required String hostId,
    String? sessionPath,
    String? toolName,
    String? requestId,
  }) async {
    if (!_allowed(AlertKind.approval)) return;
    final key = requestId == null
        ? '$hostId|${sessionPath ?? ''}'
        : '$hostId|$requestId';
    if (!_approvalRequests.add(key)) return;
    final what = toolName == null || toolName.isEmpty
        ? 'The agent is waiting for approval.'
        : 'Approve $toolName to continue?';
    await _show(
      kind: AlertKind.approval,
      hostId: hostId,
      sessionPath: sessionPath,
      title: 'Approval needed',
      body: what,
      id: _idFor('approval|$key'),
    );
  }

  Future<void> notifyTurnFinished({
    required String hostId,
    String? sessionPath,
    String? sessionName,
  }) async {
    if (!_allowed(AlertKind.turnFinished)) return;
    await _show(
      kind: AlertKind.turnFinished,
      hostId: hostId,
      sessionPath: sessionPath,
      title: 'Turn finished',
      body: sessionName == null || sessionName.isEmpty
          ? 'The agent finished its turn.'
          : '$sessionName finished its turn.',
      id: _idFor('turn|$hostId|${sessionPath ?? ''}'),
    );
  }

  Future<void> notifyBackgroundWaiting({
    required String hostId,
    required int count,
    String? sessionPath,
  }) async {
    if (!_allowed(AlertKind.backgroundWaiting)) return;
    await _show(
      kind: AlertKind.backgroundWaiting,
      hostId: hostId,
      sessionPath: sessionPath,
      title: 'Background session needs you',
      body: count == 1
          ? 'A background session is waiting for input.'
          : '$count background sessions are waiting for input.',
      id: _idFor('background|$hostId'),
    );
  }

  Future<void> notifyCronFailure({
    required String hostId,
    required String jobName,
    required String jobId,
    int? lastRunAt,
    bool needsAttention = false,
  }) async {
    if (!_allowed(AlertKind.cronFailure)) return;
    await _show(
      kind: AlertKind.cronFailure,
      hostId: hostId,
      title: needsAttention
          ? 'Scheduled task needs attention'
          : 'Scheduled task failed',
      body: needsAttention
          ? '"$jobName" finished its last run needing you. Open it for details.'
          : '"$jobName" failed on its last run.',
      id: _idFor('cron|$hostId|$jobId|${lastRunAt ?? 0}'),
    );
  }

  Future<void> _show({
    required AlertKind kind,
    required String hostId,
    required String title,
    required String body,
    required int id,
    String? sessionPath,
  }) async {
    final dedupeKey = '$kind|$hostId|${sessionPath ?? ''}';
    final now = DateTime.now();
    final last = _lastShown[dedupeKey];
    if (last != null && now.difference(last) < const Duration(seconds: 60)) {
      return;
    }
    _lastShown[dedupeKey] = now;
    final payload = jsonEncode({
      'hostId': hostId,
      if (sessionPath != null && sessionPath.isNotEmpty)
        'sessionPath': sessionPath,
    });
    try {
      await presenter.show(id: id, title: title, body: body, payload: payload);
    } catch (e) {
      debugPrint('[alerts] show failed: $e');
    }
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  @visibleForTesting
  void resetForTest() {
    _lastShown.clear();
    _approvalRequests.clear();
    appInForeground = true;
    enabled = false;
    approvals = turnFinished = backgroundWaiting = cronFailures = true;
    whileForeground = false;
  }
}
