// Run history: exact times, durations, grouping, and live upserts.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/protocol/responses.dart' show CronRun;
import 'package:acoder_mobile/features/cron/providers/cron_providers.dart';
import 'package:acoder_mobile/features/cron/widgets/cron_run_tile.dart';

CronRun _run({
  String id = 'r1',
  String jobId = 'j1',
  String status = 'ok',
  int startedAt = 0,
  int? finishedAt,
  String? summary,
  String? error,
  Map<String, dynamic>? triage,
  Map<String, String> variables = const {},
  String? model,
  String? modelSource,
  String execution = 'session',
  String? sessionFile,
  String? outputFile,
}) =>
    CronRun(
      id: id,
      jobId: jobId,
      jobName: 'Nightly',
      trigger: 'schedule',
      delivery: 'background',
      execution: execution,
      startedAt: startedAt,
      finishedAt: finishedAt,
      status: status,
      summary: summary,
      error: error,
      triage: triage,
      variables: variables,
      model: model,
      modelSource: modelSource,
      sessionFile: sessionFile,
      outputFile: outputFile,
    );

void main() {
  test('parses the full engine run record', () {
    final run = CronRun.fromJson({
      'id': 'run-1',
      'jobId': 'job-1',
      'jobName': 'Morning triage',
      'trigger': 'manual',
      'delivery': 'background',
      'execution': 'subagent',
      'startedAt': 1761467000000,
      'finishedAt': 1761467018500,
      'status': 'error',
      'error': 'model timeout',
      'summary': 'Checked 12 PRs',
      'sessionFile': '/sessions/a.jsonl',
      'model': 'ollama-cloud/kimi',
      'modelSource': 'cron',
      'subagentId': 'sub-9',
      'outputFile': '/tmp/sub-9.jsonl',
      'worktreePath': '/tmp/wt-9',
      'variables': {'branch': 'main', 'n': 3},
      'triage': {
        'outcome': 'failed',
        'recommendedAction': 'notify',
        'notify': 0.91,
      },
    });
    expect(run.jobName, 'Morning triage');
    expect(run.trigger, 'manual');
    expect(run.execution, 'subagent');
    expect(run.delivery, 'background');
    expect(run.error, 'model timeout');
    expect(run.model, 'ollama-cloud/kimi');
    expect(run.modelSource, 'cron');
    expect(run.subagentId, 'sub-9');
    expect(run.outputFile, '/tmp/sub-9.jsonl');
    expect(run.worktreePath, '/tmp/wt-9');
    expect(run.variables, {'branch': 'main', 'n': '3'});
    expect(run.triage?['outcome'], 'failed');
    expect(cronRunDuration(run), '18.5s');
    expect(cronRunTriageLabel(run.triage), 'needs attention');
  });

  test('duration formats ms, seconds and minutes', () {
    expect(
      cronRunDuration(_run(startedAt: 1000, finishedAt: 1420)),
      '420ms',
    );
    expect(
      cronRunDuration(_run(startedAt: 0, finishedAt: 2400)),
      '2.4s',
    );
    expect(
      cronRunDuration(_run(startedAt: 0, finishedAt: 130000)),
      '2m 10s',
    );
    expect(cronRunDuration(_run(status: 'running')), 'running');
  });

  test('absolute time includes seconds and omits the current year', () {
    final now = DateTime.now();
    final ms = DateTime(now.year, 10, 26, 14, 5, 22).millisecondsSinceEpoch;
    expect(cronRunAbsolute(ms), 'Oct 26, 14:05:22');
  });

  test('runs group under Today / Yesterday / dated headers', () {
    final now = DateTime.now();
    final runs = [
      _run(id: 'a', startedAt: now.millisecondsSinceEpoch),
      _run(
          id: 'b',
          startedAt:
              now.subtract(const Duration(days: 1)).millisecondsSinceEpoch),
      _run(
          id: 'c',
          startedAt:
              now.subtract(const Duration(days: 5)).millisecondsSinceEpoch),
    ];
    final groups = groupCronRunsByDay(runs);
    expect(groups.first.$1, 'Today');
    expect(groups[1].$1, 'Yesterday');
    expect(
        groups[2].$1, contains('${now.subtract(const Duration(days: 5)).day}'));
  });

  test('live upserts insert, replace and keep newest-first order', () {
    final notifier = AllCronRunsNotifier();
    notifier.upsert(_run(id: 'a', startedAt: 1000, status: 'running'));
    notifier.upsert(_run(id: 'b', startedAt: 2000, status: 'ok'));
    expect(notifier.state.map((r) => r.id).toList(), ['b', 'a']);

    notifier.upsert(_run(id: 'a', startedAt: 1000, status: 'error'));
    expect(notifier.state, hasLength(2));
    expect(notifier.state.last.status, 'error');
  });

  test('status colours and badges cover every engine status', () {
    for (final status in ['ok', 'error', 'timeout', 'running']) {
      expect(cronRunStatusColor(status), isNotNull);
      expect(cronRunStatusVariant(status), isNotNull);
    }
  });
}
