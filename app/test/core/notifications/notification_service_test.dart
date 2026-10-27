// Alert policy: settings gates, foreground suppression, dedupe, deep links.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/notifications/notification_service.dart';
import 'package:acoder_mobile/features/settings/providers/settings_providers.dart';

class _FakePresenter implements AlertPresenter {
  final List<({int id, String title, String body, String? payload})> shown = [];
  void Function(String? payload)? tap;
  bool granted = true;
  int permissionRequests = 0;

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    tap = onTap;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}

AppSettings _settings({
  bool enabled = true,
  bool foregroundAlerts = false,
}) =>
    AppSettings(
      notificationsEnabled: enabled,
      alertWhileForeground: foregroundAlerts,
    );

void main() {
  late _FakePresenter presenter;
  late NotificationService service;

  setUp(() {
    presenter = _FakePresenter();
    service = NotificationService(presenter: presenter);
    service.resetForTest();
    service.configure(_settings());
    service.appInForeground = false;
  });

  test('disabled master switch suppresses every alert', () async {
    service.configure(_settings(enabled: false));
    await service.notifyApproval(hostId: 'h', requestId: 'r1');
    expect(presenter.shown, isEmpty);
  });

  test('approval fires once per request id', () async {
    await service.notifyApproval(
        hostId: 'h', requestId: 'r1', toolName: 'bash', sessionPath: '/s');
    await service.notifyApproval(
        hostId: 'h', requestId: 'r1', toolName: 'bash', sessionPath: '/s');
    expect(presenter.shown, hasLength(1));
    expect(presenter.shown.single.title, 'Approval needed');
    expect(presenter.shown.single.body, contains('bash'));
  });

  test('foreground suppresses unless explicitly allowed', () async {
    service.appInForeground = true;
    await service.notifyTurnFinished(hostId: 'h', sessionPath: '/s');
    expect(presenter.shown, isEmpty);

    service.configure(_settings(foregroundAlerts: true));
    await service.notifyTurnFinished(hostId: 'h', sessionPath: '/s');
    expect(presenter.shown, hasLength(1));
  });

  test('turn-finished alerts are coalesced within a minute', () async {
    await service.notifyTurnFinished(hostId: 'h', sessionPath: '/s');
    await service.notifyTurnFinished(hostId: 'h', sessionPath: '/s');
    expect(presenter.shown, hasLength(1));
  });

  test('background waiting reports the count', () async {
    await service.notifyBackgroundWaiting(hostId: 'h', count: 3);
    expect(presenter.shown.single.body, contains('3 background'));
  });

  test('cron failures name the routine', () async {
    await service.notifyCronFailure(
        hostId: 'h', jobName: 'Nightly', jobId: 'j1', lastRunAt: 123);
    expect(presenter.shown.single.title, 'Scheduled task failed');
    expect(presenter.shown.single.body, contains('Nightly'));
  });

  test('payload routes back to the session', () async {
    await service.initialize();
    String? host;
    String? path;
    service.onOpenSession = (h, p) {
      host = h;
      path = p;
    };
    await service.notifyApproval(
        hostId: 'host-1', sessionPath: '/s/a.jsonl', requestId: 'r9');
    final payload = presenter.shown.single.payload!;
    expect(jsonDecode(payload)['hostId'], 'host-1');
    presenter.tap!(payload);
    expect(host, 'host-1');
    expect(path, '/s/a.jsonl');
  });
}
