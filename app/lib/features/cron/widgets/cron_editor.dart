// Cron editor — desktop CronEditor parity for a phone.
//
// The engine takes a structured schedule (`CronSchedule`), so the editor exposes
// the five kinds directly instead of parsing natural language.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' show CronJob;
import '../../../design/components/kit.dart';
import '../../../design/components/kit2.dart';
import '../../../design/components/button.dart';
import '../../../design/primitives.dart';
import '../../../design/theme.dart';
import '../../pairing/providers/connection_providers.dart';

Future<bool?> showCronEditor(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
  CronJob? job,
  String? defaultCwd,
}) {
  return showPiSheet<bool>(
    context,
    builder: (_) =>
        _CronEditor(hostId: hostId, job: job, defaultCwd: defaultCwd),
  );
}

class _CronEditor extends ConsumerStatefulWidget {
  final String hostId;
  final CronJob? job;
  final String? defaultCwd;

  const _CronEditor({required this.hostId, this.job, this.defaultCwd});

  @override
  ConsumerState<_CronEditor> createState() => _CronEditorState();
}

class _CronEditorState extends ConsumerState<_CronEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.job?.name ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: widget.job?.prompt ?? '');
  late final TextEditingController _minutes;
  late final TextEditingController _cooldown;

  String _kind = 'daily';
  String _time = '09:00';
  Set<int> _days = {1, 2, 3, 4, 5};
  DateTime _onceAt = DateTime.now().add(const Duration(hours: 1));
  String _trigger = 'turn_end';
  late bool _enabled = widget.job?.enabled ?? true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final schedule = widget.job?.schedule ?? const <String, dynamic>{};
    final kind = schedule['kind'] as String?;
    if (kind != null &&
        const {'every', 'daily', 'weekly', 'once', 'event'}.contains(kind)) {
      _kind = kind;
    }
    _time = schedule['time'] as String? ?? _time;
    final days = schedule['days'];
    if (days is List) {
      _days = days.whereType<num>().map((d) => d.toInt()).toSet();
    }
    final at = (schedule['at'] as num?)?.toInt();
    if (at != null) {
      _onceAt = DateTime.fromMillisecondsSinceEpoch(at);
    }
    _trigger = schedule['trigger'] as String? ?? _trigger;
    _minutes = TextEditingController(
        text: '${(schedule['minutes'] as num?)?.toInt() ?? 30}');
    _cooldown = TextEditingController(
        text: '${(schedule['cooldownMinutes'] as num?)?.toInt() ?? 5}');
  }

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _minutes.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  Map<String, dynamic> _schedule() {
    switch (_kind) {
      case 'every':
        return {
          'kind': 'every',
          'minutes': int.tryParse(_minutes.text.trim()) ?? 30,
        };
      case 'weekly':
        return {
          'kind': 'weekly',
          'days': _days.toList()..sort(),
          'time': _time
        };
      case 'once':
        return {'kind': 'once', 'at': _onceAt.millisecondsSinceEpoch};
      case 'event':
        return {
          'kind': 'event',
          'trigger': _trigger,
          if (int.tryParse(_cooldown.text.trim()) != null)
            'cooldownMinutes': int.parse(_cooldown.text.trim()),
        };
      default:
        return {'kind': 'daily', 'time': _time};
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final prompt = _prompt.text.trim();
    if (name.isEmpty || prompt.isEmpty) {
      _toast('Name and prompt are required.');
      return;
    }
    setState(() => _saving = true);
    final controller =
        ref.read(sessionControllerProvider(widget.hostId).notifier);
    try {
      if (widget.job == null) {
        await controller.createCronJob({
          'name': name,
          'prompt': prompt,
          'schedule': _schedule(),
          'enabled': _enabled,
          if (widget.defaultCwd != null && widget.defaultCwd!.isNotEmpty)
            'cwd': widget.defaultCwd,
        });
      } else {
        await controller.updateCronJob(widget.job!.id, {
          'name': name,
          'prompt': prompt,
          'schedule': _schedule(),
          'enabled': _enabled,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _toast('Could not save the routine.');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.job != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'Edit routine' : 'New routine',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PiColors.text,
                  ),
                ),
              ),
              PiButton(
                label: 'Cancel',
                variant: PiButtonVariant.ghost,
                size: PiButtonSize.sm,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 6),
              PiButton(
                label: editing ? 'Save' : 'Create',
                variant: PiButtonVariant.primary,
                size: PiButtonSize.sm,
                loading: _saving,
                onPressed: _saving ? null : _save,
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
              _label('NAME'),
              const SizedBox(height: 4),
              TextField(
                controller: _name,
                style: TextStyle(fontSize: 13, color: PiColors.text),
                decoration: _decoration('Morning CI triage'),
              ),
              const SizedBox(height: 12),
              _label('PROMPT'),
              const SizedBox(height: 4),
              TextField(
                controller: _prompt,
                minLines: 3,
                maxLines: 8,
                style:
                    TextStyle(fontSize: 13, height: 1.45, color: PiColors.text),
                decoration:
                    _decoration('What should the agent do when this fires?'),
              ),
              const SizedBox(height: 14),
              _label('SCHEDULE'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PiSegmentedControl<String>(
                    value: _kind,
                    options: const [
                      PiSegment('every', 'every'),
                      PiSegment('daily', 'daily'),
                      PiSegment('weekly', 'weekly'),
                      PiSegment('once', 'once'),
                      PiSegment('event', 'event'),
                    ],
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._scheduleFields(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('Enabled',
                        style: TextStyle(fontSize: 13, color: PiColors.text)),
                  ),
                  PiSwitch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Runs the prompt in this project. Overlapping runs skip while '
                'one is active.',
                style: TextStyle(fontSize: 11, color: PiColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _scheduleFields() {
    switch (_kind) {
      case 'every':
        return [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: PiColors.text),
                  decoration: _decoration('30'),
                ),
              ),
              const SizedBox(width: 8),
              Text('minutes between runs',
                  style: TextStyle(fontSize: 12, color: PiColors.textMuted)),
            ],
          ),
        ];
      case 'daily':
        return [_timeRow('Runs every day at')];
      case 'weekly':
        return [
          Wrap(
            spacing: 6,
            children: [
              for (var day = 0; day < 7; day++)
                GestureDetector(
                  onTap: () => setState(() {
                    if (!_days.remove(day)) _days.add(day);
                  }),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _days.contains(day)
                          ? PiColors.accentSoft
                          : PiColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(PiRadius.md),
                      border: Border.all(
                        color: _days.contains(day)
                            ? PiColors.accent.withValues(alpha: 0.5)
                            : PiColors.border,
                      ),
                    ),
                    child: Text(
                      const ['S', 'M', 'T', 'W', 'T', 'F', 'S'][day],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _days.contains(day)
                            ? PiColors.accent
                            : PiColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _timeRow('Runs weekly at'),
        ];
      case 'once':
        return [
          Row(
            children: [
              Text('Runs once at',
                  style: TextStyle(fontSize: 12, color: PiColors.textMuted)),
              const SizedBox(width: 8),
              PiButton(
                label: _formatDateTime(_onceAt),
                variant: PiButtonVariant.secondary,
                size: PiButtonSize.sm,
                icon: Icons.event_outlined,
                onPressed: _pickOnceAt,
              ),
            ],
          ),
        ];
      case 'event':
        return [
          PiSegmentedControl<String>(
            label: 'on',
            value: _trigger,
            options: const [
              PiSegment('turn_end', 'turn end'),
              PiSegment('git_commit', 'commit'),
            ],
            onChanged: (v) => setState(() => _trigger = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Cooldown',
                  style: TextStyle(fontSize: 12, color: PiColors.textMuted)),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _cooldown,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: PiColors.text),
                  decoration: _decoration('5'),
                ),
              ),
              const SizedBox(width: 6),
              Text('minutes',
                  style: TextStyle(fontSize: 12, color: PiColors.textMuted)),
            ],
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _timeRow(String caption) {
    return Row(
      children: [
        Text(caption,
            style: TextStyle(fontSize: 12, color: PiColors.textMuted)),
        const SizedBox(width: 8),
        PiButton(
          label: _time,
          variant: PiButtonVariant.secondary,
          size: PiButtonSize.sm,
          icon: Icons.schedule_outlined,
          onPressed: _pickTime,
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _time =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickOnceAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _onceAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_onceAt),
    );
    if (time == null || !mounted) return;
    setState(() => _onceAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  static String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontFamily: PiFonts.mono,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: PiColors.textFaint,
        ),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: PiColors.textFaint),
        filled: true,
        fillColor: PiColors.surfaceRaised,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PiRadius.md),
          borderSide: BorderSide(color: PiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PiRadius.md),
          borderSide: BorderSide(color: PiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PiRadius.md),
          borderSide: BorderSide(color: PiColors.accent, width: 1.4),
        ),
      );
}
