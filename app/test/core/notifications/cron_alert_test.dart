import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/notifications/notification_service.dart';
import 'package:acoder_mobile/core/protocol/responses.dart';

void main() {
  test('quiet successful runs do not alert', () {
    expect(
        cronAlert('ok', {'outcome': 'no_work', 'recommendedAction': 'quiet'}),
        isNull);
    expect(cronAlert('ok', {'outcome': 'ok', 'recommendedAction': 'notify'}),
        isNull);
    expect(cronAlert('ok', null), isNull);
  });

  test('failures and timeouts alert', () {
    expect(cronAlert('error', null), CronAlert.failed);
    expect(cronAlert('timeout', {'outcome': 'failed'}), CronAlert.failed);
  });

  test('a needs_user or failed triage alerts even when the run recorded ok',
      () {
    expect(
        cronAlert('ok', {'outcome': 'needs_user'}), CronAlert.needsAttention);
    expect(cronAlert('ok', {'outcome': 'failed'}), CronAlert.needsAttention);
    expect(cronAlert('ok', {'recommendedAction': 'pause'}),
        CronAlert.needsAttention);
  });

  test('CronJob parses lastTriage', () {
    final job = CronJob.fromJson({
      'id': 'j1',
      'name': 'Nightly',
      'prompt': 'do work',
      'schedule': {'kind': 'daily', 'time': '08:00'},
      'enabled': true,
      'cwd': '/tmp',
      'lastStatus': 'ok',
      'lastTriage': {
        'outcome': 'needs_user',
        'recommendedAction': 'notify',
        'notify': 0.9
      },
    });
    expect(job.lastTriage?['outcome'], 'needs_user');
    expect(cronAlert(job.lastStatus, job.lastTriage), CronAlert.needsAttention);
  });
}
