// lib/features/cron/screens/cron_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' show CronJob;
import '../../../design/primitives.dart';
import '../../../design/theme.dart';
import '../../../design/components/chip.dart';
import '../../../design/components/empty_state.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../sessions/providers/sessions_providers.dart';
import '../providers/cron_providers.dart';
import '../../../design/components/kit.dart';
import '../widgets/cron_calendar.dart';
import '../widgets/cron_run_tile.dart';
import '../widgets/cron_editor.dart';
import '../../chat/providers/chat_providers.dart';

class CronScreen extends ConsumerStatefulWidget {
  final String hostId;
  const CronScreen({super.key, required this.hostId});

  @override
  ConsumerState<CronScreen> createState() => _CronScreenState();
}

enum _CronView { list, calendar, runs }

class _CronScreenState extends ConsumerState<CronScreen> {
  bool _loading = true;
  bool _runsLoading = false;
  _CronView _view = _CronView.list;
  bool _runsErrorsOnly = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadCronJobs();
    } catch (_) {
      // Not connected yet — retry via pull-to-refresh.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadCronJobs();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionControllerProvider(widget.hostId));
    final jobs = ref.watch(cronJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled tasks')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _loading && jobs.isEmpty
            ? _skeleton(context)
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  _ActivityCard(hostId: widget.hostId, jobs: jobs),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                    child: Row(
                      children: [
                        PiSegmentedControl<_CronView>(
                          value: _view,
                          options: const [
                            PiSegment(_CronView.list, 'routines'),
                            PiSegment(_CronView.calendar, 'calendar'),
                            PiSegment(_CronView.runs, 'runs'),
                          ],
                          onChanged: _setView,
                        ),
                        const Spacer(),
                        if (_view == _CronView.runs && _runsLoading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                      ],
                    ),
                  ),
                  if (_view == _CronView.runs)
                    ..._runsChildren(context)
                  else if (_view == _CronView.calendar) ...[
                    _MonthHeader(
                      month: _month,
                      onPrevious: () => setState(() {
                        _month = DateTime(_month.year, _month.month - 1);
                        _selectedDay = null;
                      }),
                      onNext: () => setState(() {
                        _month = DateTime(_month.year, _month.month + 1);
                        _selectedDay = null;
                      }),
                    ),
                    CronCalendar(
                      jobs: jobs,
                      month: _month,
                      selectedDay: _selectedDay,
                      onSelectDay: (day) => setState(() => _selectedDay = day),
                      onOpenDay: (_) {},
                    ),
                    if (jobs.isEmpty)
                      const EmptyState(
                        icon: Icons.schedule_outlined,
                        title: 'No scheduled tasks yet',
                        hint: '',
                      ),
                    for (final job in _visibleJobs(jobs))
                      _CronJobTile(
                        key: ValueKey(job.id),
                        job: job,
                        hostId: widget.hostId,
                        onToggle: (v) => _toggle(job, v),
                        onTap: () => _openDetail(job),
                      ),
                  ] else ...[
                    if (jobs.isEmpty)
                      const EmptyState(
                        icon: Icons.schedule_outlined,
                        title: 'No scheduled tasks yet',
                        hint: '',
                      ),
                    for (final job in jobs)
                      _CronJobTile(
                        key: ValueKey(job.id),
                        job: job,
                        hostId: widget.hostId,
                        onToggle: (v) => _toggle(job, v),
                        onTap: () => _openDetail(job),
                      ),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New routine',
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _create() async {
    final created = await showCronEditor(
      context,
      ref,
      hostId: widget.hostId,
      defaultCwd: ref.read(chatStateProvider).session.cwd,
    );
    if (created == true) await _refresh();
  }

  Future<void> _refreshAll() async {
    await _refresh();
    if (_view == _CronView.runs) await _loadAllRuns();
  }

  void _setView(_CronView view) {
    setState(() => _view = view);
    if (view == _CronView.runs) {
      _loadAllRuns();
    }
  }

  Future<void> _loadAllRuns() async {
    if (_runsLoading) return;
    setState(() => _runsLoading = true);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadAllCronRuns();
    } catch (_) {
      // Offline: the last snapshot stays visible.
    }
    if (mounted) setState(() => _runsLoading = false);
  }

  List<Widget> _runsChildren(BuildContext context) {
    final all = ref.watch(allCronRunsProvider);
    final runs = _runsErrorsOnly
        ? all
            .where((r) => r.status == 'error' || r.status == 'timeout')
            .toList()
        : all;
    if (all.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: Icons.history,
            title: 'No runs recorded yet',
            hint: 'Runs appear here the moment a routine starts.',
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Row(
          children: [
            Text(
              '${all.length} run${all.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 10,
                fontFamily: PiFonts.mono,
                color: PiColors.textFaint,
              ),
            ),
            const Spacer(),
            PiSegmentedControl<bool>(
              value: _runsErrorsOnly,
              options: const [
                PiSegment(false, 'all'),
                PiSegment(true, 'errors'),
              ],
              onChanged: (v) => setState(() => _runsErrorsOnly = v),
            ),
          ],
        ),
      ),
      if (runs.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No failed runs',
            hint: 'Every recorded run finished successfully.',
          ),
        ),
      for (final group in groupCronRunsByDay(runs)) ...[
        _DayHeader(label: group.$1),
        for (final run in group.$2)
          CronRunTile(
            key: ValueKey(run.id),
            run: run,
            showJobName: true,
            onTap: () => showCronRunDetails(
              context,
              ref,
              run: run,
              onOpenSession: (sessionFile) {
                Navigator.of(context).pushNamed('/chat', arguments: {
                  'hostId': widget.hostId,
                  'sessionPath': sessionFile,
                });
              },
            ),
          ),
      ],
    ];
  }

  List<CronJob> _visibleJobs(List<CronJob> jobs) {
    final day = _selectedDay;
    if (_view != _CronView.calendar || day == null) return jobs;
    return cronJobsOnDay(jobs, day);
  }

  Future<void> _toggle(CronJob job, bool value) async {
    final notifier = ref.read(cronJobsProvider.notifier);
    final optimistic = _copy(job, enabled: value);
    notifier.upsert(optimistic);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .updateCronJob(job.id, {'enabled': value});
    } catch (_) {
      notifier.upsert(job);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update job')),
        );
      }
    }
  }

  void _openDetail(CronJob job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CronDetailPage(hostId: widget.hostId, jobId: job.id),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final c = PiColors.of(context);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─── Day header (run history) ────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontFamily: PiFonts.mono,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: PiColors.textFaint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: PiColors.border)),
        ],
      ),
    );
  }
}

// ─── Month header ────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
      child: Row(
        children: [
          Text(
            '${names[month.month - 1]} ${month.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PiColors.text,
            ),
          ),
          const Spacer(),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─── Activity (desktop Activity panel, client-derived) ────────────

/// The engine has no activity RPC, so this mirrors the desktop's attention
/// inbox from data the phone already holds: pending approvals, running
/// sub-agents and failing routines.
class _ActivityCard extends ConsumerWidget {
  final String hostId;
  final List<CronJob> jobs;

  const _ActivityCard({required this.hostId, required this.jobs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatStateProvider);
    final subagents = ref.watch(subagentsProvider);
    final approvals = chat.approvals.length;
    final running = subagents.where((a) => a.status == 'running').length;
    final failing =
        jobs.where((j) => (j.lastStatus ?? '').toLowerCase() == 'error').length;
    final background = ref
        .watch(backgroundSessionsProvider)
        .where((b) => b.status == 'needsInput')
        .length;
    if (approvals + running + failing + background == 0) {
      return const SizedBox.shrink();
    }

    Widget row(IconData icon, String label, int count, Color tone) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(icon, size: 14, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(fontSize: 12, color: PiColors.textSecondary)),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: PiFonts.mono,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: PiColors.surfaceRaised,
        borderRadius: BorderRadius.circular(PiRadius.xl),
        border: Border.all(color: PiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEEDS ATTENTION',
            style: TextStyle(
              fontSize: 9,
              fontFamily: PiFonts.mono,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: PiColors.textFaint,
            ),
          ),
          const SizedBox(height: 6),
          if (approvals > 0)
            row(Icons.verified_user_outlined, 'Approvals waiting', approvals,
                PiColors.warning),
          if (background > 0)
            row(Icons.pause_circle_outline, 'Background sessions waiting',
                background, PiColors.warning),
          if (running > 0)
            row(Icons.pending_rounded, 'Sub-agents running', running,
                PiColors.accent),
          if (failing > 0)
            row(Icons.error_outline, 'Failing routines', failing,
                PiColors.error),
        ],
      ),
    );
  }
}

// ─── Job row ─────────────────────────────────────────────────────

class _CronJobTile extends StatelessWidget {
  final CronJob job;
  final String hostId;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const _CronJobTile({
    super.key,
    required this.job,
    required this.hostId,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (job.lastStatus ?? 'never').toLowerCase();
    return Semantics(
      label: 'Scheduled task ${job.name}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.scheduleLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: PiColors.of(context).textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Next: ${_relative(job.nextRunAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: PiColors.of(context).textMuted,
                            ),
                          ),
                          StatusChip(
                            label: status,
                            variant: _statusVariant(status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: '${job.name} enabled',
                        child: Switch(
                          value: job.enabled,
                          onChanged: onToggle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(
                  height: 48,
                  width: 24,
                  child: Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail page ─────────────────────────────────────────────────

class _CronDetailPage extends ConsumerStatefulWidget {
  final String hostId;
  final String jobId;
  const _CronDetailPage({required this.hostId, required this.jobId});

  @override
  ConsumerState<_CronDetailPage> createState() => _CronDetailPageState();
}

class _CronDetailPageState extends ConsumerState<_CronDetailPage> {
  bool _loadingRuns = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRuns);
  }

  Future<void> _loadRuns() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadCronRuns(jobId: widget.jobId);
    } catch (_) {}
    if (mounted) setState(() => _loadingRuns = false);
  }

  CronJob? _job(List<CronJob> jobs) {
    for (final j in jobs) {
      if (j.id == widget.jobId) return j;
    }
    return null;
  }

  Future<void> _runNow() async {
    final controller =
        ref.read(sessionControllerProvider(widget.hostId).notifier);
    try {
      await controller.runCronNow(widget.jobId);
      await controller.loadCronRuns(jobId: widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run started')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not run now')),
        );
      }
    }
  }

  Future<void> _toggleEnabled(CronJob job, bool value) async {
    final notifier = ref.read(cronJobsProvider.notifier);
    final optimistic = _copy(job, enabled: value);
    notifier.upsert(optimistic);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .updateCronJob(job.id, {'enabled': value});
    } catch (_) {
      notifier.upsert(job);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update job')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete scheduled task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .deleteCronJob(widget.jobId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete job')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionControllerProvider(widget.hostId));
    final jobs = ref.watch(cronJobsProvider);
    final job = _job(jobs);
    final runs = ref
        .watch(cronRunsProvider)
        .where((r) => r.jobId == widget.jobId)
        .toList();
    final c = PiColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(job?.name ?? 'Scheduled task'),
        actions: [
          if (job != null)
            IconButton(
              tooltip: 'Edit routine',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () async {
                final saved = await showCronEditor(
                  context,
                  ref,
                  hostId: widget.hostId,
                  job: job,
                );
                if (saved == true) await _loadRuns();
              },
            ),
        ],
      ),
      body: job == null
          ? const Center(child: Text('Not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prompt
                Text('Prompt', style: _sectionLabel(context)),
                const SizedBox(height: 4),
                SelectableText(
                  job.prompt,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                // cwd
                Text('Working directory', style: _sectionLabel(context)),
                const SizedBox(height: 4),
                SelectableText(
                  job.cwd.isEmpty ? '—' : job.cwd,
                  style: TextStyle(
                    fontFamily: PiFonts.mono,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // Variables
                if (_variables(job).isNotEmpty) ...[
                  Text('Variables', style: _sectionLabel(context)),
                  const SizedBox(height: 4),
                  ..._variables(job).entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: SelectableText(
                            '${e.key}=${e.value}',
                            style: TextStyle(
                              fontFamily: PiFonts.mono,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                ],
                // Schedule
                Text('Schedule', style: _sectionLabel(context)),
                const SizedBox(height: 4),
                Text(job.scheduleLabel, style: const TextStyle(fontSize: 14)),
                Text('Next run: ${_relative(job.nextRunAt)}',
                    style: TextStyle(fontSize: 12, color: c.textMuted)),
                if (job.lastError != null && job.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Last error', style: _sectionLabel(context)),
                  const SizedBox(height: 4),
                  SelectableText(
                    job.lastError!,
                    style: TextStyle(
                      fontSize: 13,
                      color: PiColors.error,
                      fontFamily: PiFonts.mono,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      label: 'Run now',
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _runNow,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Run now'),
                        ),
                      ),
                    ),
                    Semantics(
                      label: job.enabled ? 'Pause' : 'Resume',
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleEnabled(job, !job.enabled),
                          icon: Icon(job.enabled
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                          label: Text(job.enabled ? 'Pause' : 'Resume'),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Delete',
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Run history', style: _sectionLabel(context)),
                const SizedBox(height: 8),
                if (_loadingRuns)
                  const Center(child: CircularProgressIndicator())
                else if (runs.isEmpty)
                  Text('No runs yet', style: TextStyle(color: c.textMuted))
                else
                  for (final group in groupCronRunsByDay(runs)) ...[
                    _DayHeader(label: group.$1),
                    for (final run in group.$2)
                      CronRunTile(
                        key: ValueKey(run.id),
                        run: run,
                        onTap: () => showCronRunDetails(
                          context,
                          ref,
                          run: run,
                          onOpenSession: (sessionFile) {
                            Navigator.of(context)
                                .pushNamed('/chat', arguments: {
                              'hostId': widget.hostId,
                              'sessionPath': sessionFile,
                            });
                          },
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────────

TextStyle _sectionLabel(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: PiColors.of(context).textMuted,
      letterSpacing: 0.6,
    );

Map<String, dynamic> _variables(CronJob job) {
  final v = job.schedule['variables'];
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

CronJob _copy(CronJob j, {bool? enabled}) => CronJob(
      id: j.id,
      name: j.name,
      prompt: j.prompt,
      schedule: j.schedule,
      enabled: enabled ?? j.enabled,
      cwd: j.cwd,
      lastRunAt: j.lastRunAt,
      nextRunAt: j.nextRunAt,
      lastStatus: j.lastStatus,
      lastError: j.lastError,
      isolated: j.isolated,
      revision: j.revision,
    );

ChipVariant _statusVariant(String status) => switch (status) {
      'ok' || 'success' || 'completed' || 'done' => ChipVariant.success,
      'error' || 'failed' || 'failure' => ChipVariant.error,
      _ => ChipVariant.muted,
    };

String _relative(int? epoch) {
  if (epoch == null) return 'never';
  final dt = epoch > 1000000000000
      ? DateTime.fromMillisecondsSinceEpoch(epoch)
      : DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  final diff = dt.difference(DateTime.now());
  String ago(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  if (diff.inSeconds.abs() < 60) return 'just now';
  if (diff.isNegative) return '${ago(diff.abs())} ago';
  return 'in ${ago(diff)}';
}
