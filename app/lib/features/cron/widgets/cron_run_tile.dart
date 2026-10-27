// Cron run history — exact times and outcomes, shared by the job detail and
// the machine-wide Runs view. Mirrors the desktop RunList fields.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' show CronRun;
import '../../../design/components/button.dart';
import '../../../design/components/kit.dart';
import '../../../design/components/kit2.dart';
import '../../../design/theme.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// `Oct 26, 14:05:22` — year included when it is not the current one.
String cronRunAbsolute(int ms, {bool seconds = true}) {
  if (ms <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final year = dt.year == now.year ? '' : ', ${dt.year}';
  final time =
      '${_two(dt.hour)}:${_two(dt.minute)}${seconds ? ':${_two(dt.second)}' : ''}';
  return '${_months[dt.month - 1]} ${dt.day}$year, $time';
}

String cronRunRelative(int ms) {
  if (ms <= 0) return '';
  final delta =
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

String cronRunDuration(CronRun run) {
  final finished = run.finishedAt;
  if (finished == null || run.status == 'running') return 'running';
  final ms = finished - run.startedAt;
  if (ms < 0) return '—';
  if (ms < 1000) return '${ms}ms';
  if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) ~/ 1000;
  return '${minutes}m ${seconds}s';
}

Color cronRunStatusColor(String status) => switch (status) {
      'ok' => PiColors.success,
      'error' => PiColors.error,
      'timeout' => PiColors.warning,
      'running' => PiColors.accent,
      _ => PiColors.textMuted,
    };

PiBadgeVariant cronRunStatusVariant(String status) => switch (status) {
      'ok' => PiBadgeVariant.success,
      'error' => PiBadgeVariant.error,
      'timeout' => PiBadgeVariant.warning,
      'running' => PiBadgeVariant.accent,
      _ => PiBadgeVariant.muted,
    };

String? cronRunTriageLabel(Map<String, dynamic>? triage) {
  if (triage == null) return null;
  final outcome = triage['outcome'];
  if (outcome == 'unavailable') return 'triage unavailable';
  final action = triage['recommendedAction'];
  if (action == 'notify') return 'needs attention';
  if (action == 'quiet') return 'quiet';
  return action == null ? null : '$action suggested';
}

String cronRunDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final delta = today.difference(DateTime(day.year, day.month, day.day)).inDays;
  if (delta <= 0) return 'Today';
  if (delta == 1) return 'Yesterday';
  final year = day.year == now.year ? '' : ', ${day.year}';
  return '${_months[day.month - 1]} ${day.day}$year';
}

/// Newest-first runs bucketed by local calendar day.
List<(String, List<CronRun>)> groupCronRunsByDay(List<CronRun> runs) {
  final groups = <String, List<CronRun>>{};
  for (final run in runs) {
    final day = DateTime.fromMillisecondsSinceEpoch(run.startedAt);
    final label = cronRunDayLabel(day);
    groups.putIfAbsent(label, () => []).add(run);
  }
  return groups.entries.map((e) => (e.key, e.value)).toList();
}

class CronRunTile extends StatelessWidget {
  final CronRun run;
  final bool showJobName;
  final VoidCallback? onTap;

  const CronRunTile({
    super.key,
    required this.run,
    this.showJobName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = cronRunStatusColor(run.status);
    final meta = [
      run.trigger,
      run.execution,
      run.delivery,
      cronRunDuration(run),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showJobName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        run.jobName.isEmpty ? run.jobId : run.jobName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PiColors.text,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        cronRunAbsolute(run.startedAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: PiFonts.mono,
                          color: PiColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cronRunRelative(run.startedAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: PiColors.textFaint,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        run.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: PiFonts.mono,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: PiFonts.mono,
                      color: PiColors.textFaint,
                    ),
                  ),
                  if (run.model != null && run.model!.isNotEmpty)
                    Text(
                      '${run.model}${run.modelSource != null ? ' (${run.modelSource})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: PiFonts.mono,
                        color: PiColors.textFaint,
                      ),
                    ),
                  if (run.summary != null && run.summary!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        run.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: PiColors.textMuted,
                        ),
                      ),
                    ),
                  if (run.error != null && run.error!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        run.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: PiColors.error,
                        ),
                      ),
                    ),
                  if (cronRunTriageLabel(run.triage) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        cronRunTriageLabel(run.triage)!,
                        style: TextStyle(
                          fontSize: 10,
                          color: PiColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: PiColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Full run record: exact timestamps, configuration, outcome and handles.
Future<void> showCronRunDetails(
  BuildContext context,
  WidgetRef ref, {
  required CronRun run,
  required void Function(String sessionFile) onOpenSession,
}) {
  return showPiSheet<void>(
    context,
    builder: (ctx) => _CronRunDetails(
      run: run,
      onOpenSession: () {
        Navigator.pop(ctx);
        onOpenSession(run.sessionFile!);
      },
    ),
  );
}

class _CronRunDetails extends StatelessWidget {
  final CronRun run;
  final VoidCallback onOpenSession;

  const _CronRunDetails({required this.run, required this.onOpenSession});

  @override
  Widget build(BuildContext context) {
    final triage = run.triage;
    final started = cronRunAbsolute(run.startedAt);
    final finished =
        run.finishedAt == null ? '—' : cronRunAbsolute(run.finishedAt!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  run.jobName.isEmpty ? 'Run' : run.jobName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PiColors.text,
                  ),
                ),
              ),
              PiBadge(
                label: run.status,
                variant: cronRunStatusVariant(run.status),
                size: PiBadgeSize.sm,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Close',
                iconSize: 18,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: PiColors.border),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _row('Started', started),
              _row('Finished', finished),
              _row('Duration', cronRunDuration(run)),
              _row('Trigger', run.trigger),
              _row('Execution', run.execution),
              _row('Delivery', run.delivery),
              if (run.model != null && run.model!.isNotEmpty)
                _row('Model',
                    '${run.model}${run.modelSource != null ? ' (${run.modelSource})' : ''}'),
              if (run.variables.isNotEmpty) ...[
                const SizedBox(height: 10),
                _label('VARIABLES'),
                for (final entry in run.variables.entries)
                  _row(entry.key, entry.value, mono: true),
              ],
              if (triage != null) ...[
                const SizedBox(height: 10),
                _label('TRIAGE'),
                _row('Outcome', '${triage['outcome'] ?? '—'}'),
                _row('Recommended', '${triage['recommendedAction'] ?? '—'}'),
                if (triage['notify'] != null)
                  _row('Notify probability', _probability(triage['notify'])),
                if (triage['retry'] != null)
                  _row('Retry probability', _probability(triage['retry'])),
                if (triage['pause'] != null)
                  _row('Pause probability', _probability(triage['pause'])),
                if (triage['error'] != null)
                  _row('Triage error', '${triage['error']}'),
              ],
              if (run.summary != null && run.summary!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _label('SUMMARY'),
                SelectableText(
                  run.summary!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: PiColors.textSecondary,
                  ),
                ),
              ],
              if (run.error != null && run.error!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _label('ERROR'),
                SelectableText(
                  run.error!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: PiColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _label('HANDLES'),
              if (run.sessionFile != null && run.sessionFile!.isNotEmpty)
                _handle(context, 'Session', run.sessionFile!),
              if (run.outputFile != null && run.outputFile!.isNotEmpty)
                _handle(context, 'Subagent log', run.outputFile!),
              if (run.worktreePath != null && run.worktreePath!.isNotEmpty)
                _handle(context, 'Worktree', run.worktreePath!),
              if (run.subagentId != null && run.subagentId!.isNotEmpty)
                _row('Subagent', run.subagentId!, mono: true),
              if (run.sessionFile == null &&
                  run.outputFile == null &&
                  run.worktreePath == null)
                Text('No files recorded for this run.',
                    style: TextStyle(fontSize: 11, color: PiColors.textMuted)),
              if (run.sessionFile != null && run.sessionFile!.isNotEmpty) ...[
                const SizedBox(height: 14),
                PiButton(
                  label: 'Open run session',
                  variant: PiButtonVariant.primary,
                  size: PiButtonSize.sm,
                  icon: Icons.open_in_new,
                  onPressed: onOpenSession,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _probability(Object? value) {
    if (value is num) {
      return '${(value * 100).toStringAsFixed(0)}%';
    }
    return '$value';
  }

  Widget _row(String label, String value, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: PiColors.textMuted),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontFamily: mono ? PiFonts.mono : null,
                  color: PiColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _handle(BuildContext context, String label, String path) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: PiColors.textMuted)),
            ),
            Expanded(
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: PiFonts.mono,
                  color: PiColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy path',
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Path copied')),
                );
              },
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontFamily: PiFonts.mono,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: PiColors.textFaint,
          ),
        ),
      );
}
