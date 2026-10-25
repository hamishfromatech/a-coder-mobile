// Office editors — coworker and huddle CRUD, desktop panel parity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart'
    show Coworker, HuddleSummary, OfficeErrand;
import '../../../design/components/button.dart';
import '../../../design/components/kit.dart';
import '../../../design/components/kit2.dart';
import '../../../design/primitives.dart';
import '../../../design/theme.dart';
import '../../pairing/providers/connection_providers.dart';

Future<bool?> showCoworkerEditor(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
  Coworker? coworker,
}) {
  return showPiSheet<bool>(
    context,
    builder: (_) => _CoworkerEditor(hostId: hostId, coworker: coworker),
  );
}

Future<bool?> showHuddleEditor(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
  required List<Coworker> coworkers,
  HuddleSummary? huddle,
}) {
  return showPiSheet<bool>(
    context,
    builder: (_) => _HuddleEditor(
      hostId: hostId,
      coworkers: coworkers,
      huddle: huddle,
    ),
  );
}

Future<bool?> showErrandEditor(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
  required List<Coworker> coworkers,
  required List<HuddleSummary> huddles,
  OfficeErrand? errand,
}) {
  return showPiSheet<bool>(
    context,
    builder: (_) => _ErrandEditor(
      hostId: hostId,
      coworkers: coworkers,
      huddles: huddles,
      errand: errand,
    ),
  );
}

class _ErrandEditor extends ConsumerStatefulWidget {
  final String hostId;
  final List<Coworker> coworkers;
  final List<HuddleSummary> huddles;
  final OfficeErrand? errand;

  const _ErrandEditor({
    required this.hostId,
    required this.coworkers,
    required this.huddles,
    this.errand,
  });

  @override
  ConsumerState<_ErrandEditor> createState() => _ErrandEditorState();
}

class _ErrandEditorState extends ConsumerState<_ErrandEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.errand?.name ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: widget.errand?.prompt ?? '');
  late final TextEditingController _minutes;
  late String _coworkerId = widget.errand?.coworkerId ??
      (widget.coworkers.isNotEmpty ? widget.coworkers.first.id : '');
  late String _kind = (widget.errand?.schedule['kind'] as String?) ?? 'daily';
  late String _time = (widget.errand?.schedule['time'] as String?) ?? '09:00';
  late DateTime _onceAt = DateTime.fromMillisecondsSinceEpoch(
      (widget.errand?.schedule['at'] as num?)?.toInt() ??
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch);
  late bool _continuity = widget.errand?.continuity ?? true;
  late String _delivery = widget.errand?.delivery ?? 'dm';
  late String? _huddleId = widget.errand?.huddleId;
  late bool _enabled = widget.errand?.enabled ?? true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minutes = TextEditingController(
        text: '${(widget.errand?.schedule['minutes'] as num?)?.toInt() ?? 60}');
  }

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Map<String, dynamic> _schedule() => switch (_kind) {
        'every' => {
            'kind': 'every',
            'minutes': int.tryParse(_minutes.text.trim()) ?? 60,
          },
        'once' => {
            'kind': 'once',
            'at': _onceAt.millisecondsSinceEpoch,
          },
        _ => {'kind': 'daily', 'time': _time},
      };

  Future<void> _save() async {
    if (_coworkerId.isEmpty) {
      _toast('Create a coworker first.');
      return;
    }
    final name = _name.text.trim();
    final prompt = _prompt.text.trim();
    if (name.isEmpty || prompt.isEmpty) {
      _toast('Name and prompt are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .saveErrand({
        if (widget.errand != null) 'id': widget.errand!.id,
        'coworkerId': _coworkerId,
        'name': name,
        'prompt': prompt,
        'schedule': _schedule(),
        'continuity': _continuity,
        'delivery': _delivery,
        if (_delivery == 'huddle' && _huddleId != null) 'huddleId': _huddleId,
        'enabled': _enabled,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast('Could not save the errand.');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .deleteErrand(widget.errand!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast('Could not delete the errand.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.errand != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(
          title: editing ? 'Edit errand' : 'New errand',
          busy: _saving,
          saveLabel: editing ? 'Save' : 'Create',
          onSave: _saving ? null : _save,
          onDelete: editing ? _delete : null,
        ),
        Divider(height: 1, color: PiColors.border),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _label('COWORKER'),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _coworkerId.isEmpty ? null : _coworkerId,
                decoration: _decoration('Who runs this errand?'),
                dropdownColor: PiColors.surfaceOverlay,
                items: [
                  for (final c in widget.coworkers)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _coworkerId = v ?? ''),
              ),
              const SizedBox(height: 12),
              _Field(label: 'NAME', controller: _name, hint: 'Weekly digest'),
              _Field(
                label: 'PROMPT',
                controller: _prompt,
                hint: 'What should this coworker do?',
                lines: 3,
              ),
              _label('SCHEDULE'),
              const SizedBox(height: 6),
              PiSegmentedControl<String>(
                value: _kind,
                options: const [
                  PiSegment('every', 'every'),
                  PiSegment('daily', 'daily'),
                  PiSegment('once', 'once'),
                ],
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 10),
              if (_kind == 'every')
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _minutes,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('60'),
                        style: TextStyle(fontSize: 13, color: PiColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('minutes',
                        style:
                            TextStyle(fontSize: 12, color: PiColors.textMuted)),
                  ],
                )
              else if (_kind == 'daily')
                Row(
                  children: [
                    Text('Runs daily at',
                        style:
                            TextStyle(fontSize: 12, color: PiColors.textMuted)),
                    const SizedBox(width: 8),
                    PiButton(
                      label: _time,
                      variant: PiButtonVariant.secondary,
                      size: PiButtonSize.sm,
                      icon: Icons.schedule_outlined,
                      onPressed: _pickTime,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Text('Runs once at',
                        style:
                            TextStyle(fontSize: 12, color: PiColors.textMuted)),
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
              const SizedBox(height: 14),
              _label('DELIVERY'),
              const SizedBox(height: 6),
              PiSegmentedControl<String>(
                value: _delivery,
                options: const [
                  PiSegment('dm', 'dm'),
                  PiSegment('huddle', 'huddle'),
                ],
                onChanged: (v) => setState(() => _delivery = v),
              ),
              if (_delivery == 'huddle') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue:
                      _huddleId != null && _huddleExists() ? _huddleId : null,
                  decoration: _decoration('Huddle'),
                  dropdownColor: PiColors.surfaceOverlay,
                  items: [
                    for (final h in widget.huddles)
                      DropdownMenuItem(value: h.id, child: Text(h.name)),
                  ],
                  onChanged: (v) => setState(() => _huddleId = v),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Continuity',
                            style:
                                TextStyle(fontSize: 13, color: PiColors.text)),
                        Text('Keep the coworker’s session history',
                            style: TextStyle(
                                fontSize: 11, color: PiColors.textMuted)),
                      ],
                    ),
                  ),
                  PiSwitch(
                    value: _continuity,
                    onChanged: (v) => setState(() => _continuity = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
            ],
          ),
        ),
      ],
    );
  }

  bool _huddleExists() => widget.huddles.any((h) => h.id == _huddleId);

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
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
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

class _CoworkerEditor extends ConsumerStatefulWidget {
  final String hostId;
  final Coworker? coworker;
  const _CoworkerEditor({required this.hostId, this.coworker});

  @override
  ConsumerState<_CoworkerEditor> createState() => _CoworkerEditorState();
}

class _CoworkerEditorState extends ConsumerState<_CoworkerEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.coworker?.name ?? '');
  late final TextEditingController _handle =
      TextEditingController(text: widget.coworker?.handle ?? '');
  late final TextEditingController _title =
      TextEditingController(text: widget.coworker?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.coworker?.description ?? '');
  late final TextEditingController _model =
      TextEditingController(text: widget.coworker?.model ?? '');
  late final TextEditingController _soul = TextEditingController();
  late String _autonomy = widget.coworker?.autonomy ?? 'supervised';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _title.dispose();
    _description.dispose();
    _model.dispose();
    _soul.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Name is required.');
      return;
    }
    final creating = widget.coworker == null;
    if (creating && _soul.text.trim().isEmpty) {
      _toast('Soul is required for a new coworker.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .saveCoworker({
        if (!creating) 'id': widget.coworker!.id,
        'name': name,
        'handle': _handle.text.trim().isEmpty
            ? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            : _handle.text.trim(),
        if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        if (_model.text.trim().isNotEmpty) 'model': _model.text.trim(),
        if (creating) 'soul': _soul.text.trim(),
        'autonomy': _autonomy,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast('Could not save the coworker.');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.coworker!.name}?'),
        content:
            const Text('Their sessions stay on disk; the roster entry goes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: PiColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .deleteCoworker(widget.coworker!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast('Could not delete the coworker.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.coworker != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(
          title: editing ? 'Edit coworker' : 'New coworker',
          busy: _saving,
          saveLabel: editing ? 'Save' : 'Create',
          onSave: _saving ? null : _save,
          onDelete: editing ? _delete : null,
        ),
        Divider(height: 1, color: PiColors.border),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Field(label: 'NAME', controller: _name, hint: 'Atlas'),
              _Field(label: 'HANDLE', controller: _handle, hint: 'atlas'),
              _Field(label: 'TITLE', controller: _title, hint: 'Scout'),
              _Field(
                label: 'DESCRIPTION',
                controller: _description,
                hint: 'What this coworker is for',
                lines: 2,
              ),
              _Field(
                label: 'MODEL (provider/model)',
                controller: _model,
                hint: 'inherits the session default when empty',
              ),
              if (!editing)
                _Field(
                  label: 'SOUL',
                  controller: _soul,
                  hint: 'Persona pinned into their session at birth',
                  lines: 4,
                ),
              const SizedBox(height: 6),
              Text('AUTONOMY',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: PiFonts.mono,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: PiColors.textFaint,
                  )),
              const SizedBox(height: 6),
              PiSegmentedControl<String>(
                value: _autonomy,
                options: const [
                  PiSegment('supervised', 'supervised'),
                  PiSegment('auto', 'auto'),
                ],
                onChanged: (v) => setState(() => _autonomy = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HuddleEditor extends ConsumerStatefulWidget {
  final String hostId;
  final List<Coworker> coworkers;
  final HuddleSummary? huddle;

  const _HuddleEditor({
    required this.hostId,
    required this.coworkers,
    this.huddle,
  });

  @override
  ConsumerState<_HuddleEditor> createState() => _HuddleEditorState();
}

class _HuddleEditorState extends ConsumerState<_HuddleEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.huddle?.name ?? '');
  late final Set<String> _members = {...?widget.huddle?.members};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .saveHuddle(
            id: widget.huddle?.id,
            name: name,
            members: _members.toList(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save the huddle.')));
      }
    }
  }

  Future<void> _delete() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .deleteHuddle(widget.huddle!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not delete.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.huddle != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(
          title: editing ? 'Edit huddle' : 'New huddle',
          busy: _saving,
          saveLabel: editing ? 'Save' : 'Create',
          onSave: _saving ? null : _save,
          onDelete: editing ? _delete : null,
        ),
        Divider(height: 1, color: PiColors.border),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Field(label: 'NAME', controller: _name, hint: 'Morning standup'),
              const SizedBox(height: 8),
              Text('MEMBERS',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: PiFonts.mono,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: PiColors.textFaint,
                  )),
              const SizedBox(height: 6),
              if (widget.coworkers.isEmpty)
                Text('No coworkers yet.',
                    style: TextStyle(fontSize: 12, color: PiColors.textMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in widget.coworkers)
                      _MemberChip(
                        label: c.name,
                        selected: _members.contains(c.id),
                        onTap: () => setState(() {
                          if (!_members.remove(c.id)) _members.add(c.id);
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorHeader extends StatelessWidget {
  final String title;
  final String saveLabel;
  final bool busy;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;

  const _EditorHeader({
    required this.title,
    required this.saveLabel,
    required this.busy,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PiColors.text)),
          ),
          if (onDelete != null)
            PiIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Delete',
              size: PiButtonSize.iconSm,
              variant: PiButtonVariant.ghostDanger,
              onPressed: onDelete,
            ),
          const SizedBox(width: 4),
          PiButton(
            label: 'Cancel',
            variant: PiButtonVariant.ghost,
            size: PiButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: 6),
          PiButton(
            label: saveLabel,
            variant: PiButtonVariant.primary,
            size: PiButtonSize.sm,
            loading: busy,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int lines;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.lines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 9,
                fontFamily: PiFonts.mono,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: PiColors.textFaint,
              )),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines * 2,
            style: TextStyle(fontSize: 13, height: 1.45, color: PiColors.text),
            decoration: InputDecoration(
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
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MemberChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PiRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PiColors.accentSoft : PiColors.surfaceRaised,
          borderRadius: BorderRadius.circular(PiRadius.md),
          border: Border.all(
            color: selected
                ? PiColors.accent.withValues(alpha: 0.5)
                : PiColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: selected ? PiColors.accent : PiColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
