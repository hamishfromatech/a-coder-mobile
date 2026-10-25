// Calendar projection: schedule kinds → days in the month.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/protocol/responses.dart' show CronJob;
import 'package:acoder_mobile/features/cron/widgets/cron_calendar.dart';

CronJob _job(String id, Map<String, dynamic> schedule, {String? status}) =>
    CronJob(
      id: id,
      name: id,
      prompt: 'p',
      schedule: schedule,
      enabled: true,
      cwd: '/work',
      lastStatus: status,
    );

void main() {
  final monday = DateTime(2026, 10, 26); // weekday 1 (JS day 1)
  final tuesday = DateTime(2026, 10, 27);

  test('every/daily jobs run every day', () {
    final jobs = [
      _job('every', {'kind': 'every', 'minutes': 30}),
      _job('daily', {'kind': 'daily', 'time': '09:00'}),
    ];
    expect(cronJobsOnDay(jobs, monday).length, 2);
    expect(cronJobsOnDay(jobs, tuesday).length, 2);
  });

  test('weekly jobs match JS weekday numbers', () {
    final job = _job('weekly', {
      'kind': 'weekly',
      'days': [1], // Monday
      'time': '08:00',
    });
    expect(cronJobsOnDay([job], monday), hasLength(1));
    expect(cronJobsOnDay([job], tuesday), isEmpty);
  });

  test('once jobs match the exact date', () {
    final at = DateTime(2026, 10, 27, 14, 30).millisecondsSinceEpoch;
    final job = _job('once', {'kind': 'once', 'at': at});
    expect(cronJobsOnDay([job], monday), isEmpty);
    expect(cronJobsOnDay([job], tuesday), hasLength(1));
    expect(cronTimeLabel(job), '14:30');
  });

  test('event jobs never appear on the calendar', () {
    final job = _job('event', {'kind': 'event', 'trigger': 'git_commit'});
    expect(cronJobsOnDay([job], monday), isEmpty);
    expect(cronTimeLabel(job), 'on git_commit');
  });
}
