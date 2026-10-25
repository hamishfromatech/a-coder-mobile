// Cron calendar — desktop `CronCalendar` month view, mobile-adapted.
//
// Occurrences are derived from each job's schedule (the engine's `nextRunAt`
// only covers the next fire, not a month). Event-triggered routines have no
// calendar position and are listed separately in the day sheet.
library;

import 'package:flutter/material.dart';

import '../../../core/protocol/responses.dart' show CronJob;
import '../../../design/primitives.dart';
import '../../../design/theme.dart';

/// Every job due on [day] (local time).
List<CronJob> cronJobsOnDay(List<CronJob> jobs, DateTime day) {
  return jobs.where((job) {
    final schedule = job.schedule;
    final kind = schedule['kind'] as String?;
    switch (kind) {
      case 'every':
      case 'daily':
        return true;
      case 'weekly':
        final days = schedule['days'];
        // JS day numbers: 0 = Sunday.
        final jsDay = day.weekday % 7;
        return days is List &&
            days.whereType<num>().any((d) => d.toInt() == jsDay);
      case 'once':
        final at = (schedule['at'] as num?)?.toInt();
        if (at == null) return false;
        final when = DateTime.fromMillisecondsSinceEpoch(at);
        return when.year == day.year &&
            when.month == day.month &&
            when.day == day.day;
      default:
        return false;
    }
  }).toList();
}

/// "HH:MM" for jobs with a fixed time, "every Nm" / "event" otherwise.
String cronTimeLabel(CronJob job) {
  final schedule = job.schedule;
  switch (schedule['kind'] as String?) {
    case 'daily':
    case 'weekly':
      return schedule['time'] as String? ?? '';
    case 'every':
      final minutes = (schedule['minutes'] as num?)?.toInt() ?? 0;
      return 'every ${minutes}m';
    case 'once':
      final at = (schedule['at'] as num?)?.toInt();
      if (at == null) return '';
      final when = DateTime.fromMillisecondsSinceEpoch(at);
      return '${when.hour.toString().padLeft(2, '0')}:'
          '${when.minute.toString().padLeft(2, '0')}';
    case 'event':
      return 'on ${schedule['trigger'] ?? 'event'}';
    default:
      return '';
  }
}

class CronCalendar extends StatelessWidget {
  final List<CronJob> jobs;
  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime?> onSelectDay;
  final void Function(DateTime day) onOpenDay;

  const CronCalendar({
    super.key,
    required this.jobs,
    required this.month,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first grid
    final today = DateTime.now();
    final cells = <Widget>[];
    const weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final due = cronJobsOnDay(jobs, date);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = selectedDay != null &&
          date.year == selectedDay!.year &&
          date.month == selectedDay!.month &&
          date.day == selectedDay!.day;
      cells.add(
        _DayCell(
          day: day,
          count: due.length,
          isToday: isToday,
          isSelected: isSelected,
          onTap: () {
            onSelectDay(isSelected ? null : date);
            if (!isSelected) onOpenDay(date);
          },
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: PiColors.surfaceRaised,
        borderRadius: BorderRadius.circular(PiRadius.xl),
        border: Border.all(color: PiColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: PiFonts.mono,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: PiColors.textFaint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PiRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? PiColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(PiRadius.md),
          border: isToday
              ? Border.all(color: PiColors.accent.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected || isToday
                    ? PiColors.accent
                    : PiColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            if (count > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++)
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: PiColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}
