import 'package:acoder_mobile/core/protocol/responses.dart' show CronJob;
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:acoder_mobile/features/cron/providers/cron_providers.dart';
import 'package:acoder_mobile/features/cron/screens/cron_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CronJob _job({
  String id = 'j1',
  String name = 'Nightly build',
  String prompt = 'run build',
  Map<String, dynamic> schedule = const {'kind': 'daily', 'time': '02:00'},
  bool enabled = true,
  String cwd = '/tmp',
  int? nextRunAt,
  String? lastStatus,
  String? lastError,
}) =>
    CronJob(
      id: id,
      name: name,
      prompt: prompt,
      schedule: schedule,
      enabled: enabled,
      cwd: cwd,
      lastRunAt: null,
      nextRunAt: nextRunAt,
      lastStatus: lastStatus,
      lastError: lastError,
    );

void main() {
  testWidgets('renders list from overridden provider', (tester) async {
    final jobs = [_job(), _job(id: 'j2', name: 'Hourly sync')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) {
            final n = CronJobsNotifier();
            n.update(jobs);
            return n;
          }),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const CronScreen(hostId: 'h1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Nightly build'), findsOneWidget);
    expect(find.text('Hourly sync'), findsOneWidget);
    expect(find.text('daily 02:00'), findsNWidgets(2));
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) => CronJobsNotifier()),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const CronScreen(hostId: 'h1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('No scheduled tasks — create one from the desktop or the CLI'),
      findsOneWidget,
    );
  });

  testWidgets('schedule labels render', (tester) async {
    final jobs = [
      _job(schedule: const {'kind': 'every', 'minutes': 30}),
      _job(id: 'j2', schedule: const {'kind': 'weekly', 'days': [1, 3], 'time': '09:00'}),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) {
            final n = CronJobsNotifier();
            n.update(jobs);
            return n;
          }),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const CronScreen(hostId: 'h1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('every 30m'), findsOneWidget);
    expect(find.textContaining('weekly'), findsOneWidget);
  });

  testWidgets('error status renders', (tester) async {
    final jobs = [_job(lastStatus: 'error')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) {
            final n = CronJobsNotifier();
            n.update(jobs);
            return n;
          }),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const CronScreen(hostId: 'h1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('error'), findsOneWidget);
  });

  testWidgets('delete confirmation shows', (tester) async {
    final jobs = [_job()];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) {
            final n = CronJobsNotifier();
            n.update(jobs);
            return n;
          }),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const CronScreen(hostId: 'h1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // tap row
    await tester.tap(find.text('Nightly build'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Delete scheduled task?'), findsOneWidget);
  });

  testWidgets('text scale 2.0 no overflow', (tester) async {
    final jobs = [_job(name: 'A very long scheduled task name that wraps')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          cronJobsProvider.overrideWith((ref) {
            final n = CronJobsNotifier();
            n.update(jobs);
            return n;
          }),
        ],
        child: MaterialApp(
          theme: PiTheme.dark,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: CronScreen(hostId: 'h1'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}


class _FakeSessionController extends SessionController {
  _FakeSessionController(super.ref, super.hostId);
  @override
  Future<void> loadCronJobs() async {}
  @override
  Future<void> loadCronRuns({String? jobId}) async {}
  @override
  Future<void> runCronNow(String jobId, {Map<String, String>? variables}) async {}
  @override
  Future<void> deleteCronJob(String jobId) async {}
  @override
  Future<void> updateCronJob(String jobId, Map<String, dynamic> patch) async {}
  @override
  // ignore: must_call_super
  void dispose() {}
}
