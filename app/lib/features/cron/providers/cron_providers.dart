// Cron (scheduled tasks) state — doc 03 §5, plan M6.1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' as responses;

/// Jobs from `cron_list` and every `cron_update` push.
final cronJobsProvider =
    StateNotifierProvider<CronJobsNotifier, List<responses.CronJob>>((ref) {
  return CronJobsNotifier();
});

class CronJobsNotifier extends StateNotifier<List<responses.CronJob>> {
  CronJobsNotifier() : super(const []);

  void update(List<responses.CronJob> jobs) => state = jobs;
  void clear() => state = const [];

  /// Apply one job from a `cron_update`/`cron_update` response without a full
  /// snapshot refresh.
  void upsert(responses.CronJob job) {
    final next = [...state];
    final index = next.indexWhere((j) => j.id == job.id);
    if (index >= 0) {
      next[index] = job;
    } else {
      next.add(job);
    }
    state = next;
  }

  void remove(String jobId) =>
      state = state.where((j) => j.id != jobId).toList();
}

/// Run history from `cron_runs` (optionally per job).
final cronRunsProvider =
    StateNotifierProvider<CronRunsNotifier, List<responses.CronRun>>((ref) {
  return CronRunsNotifier();
});

class CronRunsNotifier extends StateNotifier<List<responses.CronRun>> {
  CronRunsNotifier() : super(const []);
  void update(List<responses.CronRun> runs) => state = runs;
  void clear() => state = const [];
}

/// Selected job for the detail pane (null = list view).
final selectedCronJobProvider = StateProvider<String?>((ref) => null);
