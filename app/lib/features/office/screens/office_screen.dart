// lib/features/office/screens/office_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' as responses;
import '../../../design/theme.dart';
import '../../../design/components/button.dart';
import '../../../design/components/kit2.dart';
import '../../../design/components/chip.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/status_dot.dart';
import '../../pairing/providers/connection_providers.dart';
import '../providers/office_providers.dart';
import '../widgets/office_editors.dart';

class OfficeScreen extends ConsumerStatefulWidget {
  final String hostId;
  const OfficeScreen({super.key, required this.hostId});

  @override
  ConsumerState<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends ConsumerState<OfficeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadOffice();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    try {
      await ref
          .read(sessionControllerProvider(widget.hostId).notifier)
          .loadOffice();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionControllerProvider(widget.hostId));
    final snap = ref.watch(officeSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Office')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading && snap.isEmpty
            ? _skeleton(context)
            : snap.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.people_outline_rounded,
                        title:
                            'No coworkers yet — set up Your Office on the desktop',
                        hint: '',
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (snap.pendingPrompts.isNotEmpty)
                        _PendingPromptsBanner(
                          count: snap.pendingPrompts.length,
                          onTap: () => _openPrompts(snap.pendingPrompts),
                        ),
                      if (snap.coworkers.isNotEmpty) ...[
                        const _SectionHeader('Coworkers'),
                        for (final c in snap.coworkers)
                          _CoworkerRow(
                            coworker: c,
                            status: snap.statuses[c.id] ?? '',
                            onTap: () =>
                                _openCoworker(c, snap.statuses[c.id] ?? ''),
                          ),
                      ],
                      if (snap.huddles.isNotEmpty) ...[
                        const _SectionHeader('Huddles'),
                        for (final h in _sortedHuddles(snap.huddles))
                          _HuddleRow(
                            huddle: h,
                            onTap: () => _openHuddle(h),
                            onLongPress: () async {
                              final saved = await showHuddleEditor(
                                context,
                                ref,
                                hostId: widget.hostId,
                                coworkers: snap.coworkers,
                                huddle: h,
                              );
                              if (saved == true) await _refresh();
                            },
                          ),
                      ],
                      if (snap.errands.isNotEmpty) ...[
                        const _SectionHeader('Errands'),
                        for (final e in snap.errands)
                          _ErrandRow(
                            errand: e,
                            coworkerName: _nameFor(snap, e.coworkerId),
                            onTap: () => _openErrand(snap, e),
                          ),
                      ],
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New coworker or huddle',
        onPressed: () => _openCreateMenu(snap),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openCreateMenu(responses.OfficeSnapshot snap) async {
    final choice = await showPiSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('New coworker'),
              onTap: () => Navigator.pop(ctx, 'coworker'),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('New huddle'),
              onTap: () => Navigator.pop(ctx, 'huddle'),
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text('New errand'),
              enabled: snap.coworkers.isNotEmpty,
              onTap: () => Navigator.pop(ctx, 'errand'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'coworker') {
      final saved =
          await showCoworkerEditor(context, ref, hostId: widget.hostId);
      if (saved == true) await _refresh();
    } else if (choice == 'huddle') {
      final saved = await showHuddleEditor(
        context,
        ref,
        hostId: widget.hostId,
        coworkers: snap.coworkers,
      );
      if (saved == true) await _refresh();
    } else if (choice == 'errand') {
      final saved = await showErrandEditor(
        context,
        ref,
        hostId: widget.hostId,
        coworkers: snap.coworkers,
        huddles: snap.huddles,
      );
      if (saved == true) await _refresh();
    }
  }

  List<responses.HuddleSummary> _sortedHuddles(
      List<responses.HuddleSummary> list) {
    final pinned = list.where((h) => h.pinned).toList();
    final rest = list.where((h) => !h.pinned).toList();
    return [...pinned, ...rest];
  }

  static String _nameFor(responses.OfficeSnapshot snap, String id) {
    for (final c in snap.coworkers) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  Future<void> _openErrand(
      responses.OfficeSnapshot snap, responses.OfficeErrand errand) async {
    final action = await showPiSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(errand.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(errand.scheduleLabel),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Run now'),
              onTap: () => Navigator.pop(ctx, 'run'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: PiColors.error),
              title: Text('Delete', style: TextStyle(color: PiColors.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final controller =
        ref.read(sessionControllerProvider(widget.hostId).notifier);
    switch (action) {
      case 'run':
        try {
          await controller.runErrand(errand.id);
          if (mounted) await _refresh();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not run the errand')));
          }
        }
      case 'edit':
        final saved = await showErrandEditor(
          context,
          ref,
          hostId: widget.hostId,
          coworkers: snap.coworkers,
          huddles: snap.huddles,
          errand: errand,
        );
        if (saved == true) await _refresh();
      case 'delete':
        try {
          await controller.deleteErrand(errand.id);
          if (mounted) await _refresh();
        } catch (_) {}
    }
  }

  void _openCoworker(responses.Coworker c, String status) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              if (c.handle.isNotEmpty)
                Text('@${c.handle}',
                    style: TextStyle(
                        fontSize: 13, color: PiColors.of(ctx).textMuted)),
              const SizedBox(height: 12),
              if (c.description != null && c.description!.isNotEmpty)
                Text(c.description!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              _detailLine(ctx, 'Autonomy', c.autonomy),
              if (c.model != null && c.model!.isNotEmpty)
                _detailLine(ctx, 'Model', c.model!),
              if (c.voice != null && c.voice!.isNotEmpty)
                _detailLine(ctx, 'Voice', c.voice!),
              if (c.title != null && c.title!.isNotEmpty)
                _detailLine(ctx, 'Title', c.title!),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PiButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: PiButtonVariant.outline,
                  size: PiButtonSize.sm,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final saved = await showCoworkerEditor(
                      context,
                      ref,
                      hostId: widget.hostId,
                      coworker: c,
                    );
                    if (saved == true) await _refresh();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PiColors.of(ctx).textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _openHuddle(responses.HuddleSummary h) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OfficeHuddleScreen(hostId: widget.hostId, huddleId: h.id),
      ),
    );
  }

  void _openPrompts(List<Map<String, dynamic>> prompts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _PendingPromptsSheet(prompts: prompts, hostId: widget.hostId),
    );
  }

  Widget _skeleton(BuildContext context) {
    final c = PiColors.of(context);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
              color: c.surfaceRaised, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _PendingPromptsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingPromptsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final plural = count == 1 ? '' : 's';
    return Semantics(
      label: '$count pending prompt$plural, tap to view',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: PiColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PiColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_chat_unread_rounded,
                  size: 18, color: PiColors.warning),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('$count pending prompt$plural',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingPromptsSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> prompts;
  final String hostId;
  const _PendingPromptsSheet({required this.prompts, required this.hostId});

  @override
  ConsumerState<_PendingPromptsSheet> createState() =>
      _PendingPromptsSheetState();
}

class _PendingPromptsSheetState extends ConsumerState<_PendingPromptsSheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.prompts.length,
          itemBuilder: (ctx, i) {
            final p = widget.prompts[i];
            final reqId = _requestId(p);
            final title = _title(p);
            final options = _options(p);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in options)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: reqId == null
                                ? null
                                : () {
                                    ref
                                        .read(sessionControllerProvider(
                                                widget.hostId)
                                            .notifier)
                                        .respondOfficePrompt(reqId, opt);
                                  },
                            child: Text(opt),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String? _requestId(Map<String, dynamic> p) {
    final v = p['requestId'] ?? p['request_id'] ?? p['request'] ?? p['id'];
    return v?.toString();
  }

  static String _title(Map<String, dynamic> p) {
    final v =
        p['title'] ?? p['prompt'] ?? p['text'] ?? p['message'] ?? p['name'];
    return v?.toString() ?? '';
  }

  static List<String> _options(Map<String, dynamic> p) {
    final raw = p['options'] ?? p['choices'] ?? p['actions'] ?? p['responses'];
    if (raw is List) {
      final out = <String>[];
      for (final item in raw) {
        if (item is String) {
          out.add(item);
        } else if (item is Map) {
          final m = item.cast<String, dynamic>();
          final label =
              m['label'] ?? m['value'] ?? m['text'] ?? m['title'] ?? m['name'];
          if (label != null) out.add(label.toString());
        }
      }
      return out;
    }
    return const [];
  }
}

class _CoworkerRow extends StatelessWidget {
  final responses.Coworker coworker;
  final String status;
  final VoidCallback onTap;
  const _CoworkerRow(
      {required this.coworker, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final dotType = (s == 'running' || s == 'working' || s == 'busy')
        ? StatusDotType.live
        : (s == 'error' ? StatusDotType.error : StatusDotType.idle);
    final subtitle = coworker.title ?? coworker.description ?? '';
    return Semantics(
      label: 'Coworker ${coworker.name}',
      button: true,
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
                SizedBox(
                    width: 24,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StatusDot(type: dotType))),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(coworker.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (coworker.handle.isNotEmpty)
                            Text(' @${coworker.handle}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: PiColors.of(context).textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: PiColors.of(context).textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      if (coworker.model != null &&
                          coworker.model!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        StatusChip(
                            label: coworker.model!,
                            variant: ChipVariant.accent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    );
  }
}

class _HuddleRow extends StatelessWidget {
  final responses.HuddleSummary huddle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _HuddleRow({
    required this.huddle,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final members = huddle.members.length;
    return Semantics(
      label: 'Huddle ${huddle.name}',
      button: true,
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
                if (huddle.pinned)
                  Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Icon(Icons.push_pin_rounded,
                          size: 16, color: PiColors.accent)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(huddle.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (huddle.preview != null &&
                          huddle.preview!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(huddle.preview!,
                            style: TextStyle(
                                fontSize: 13,
                                color: PiColors.of(context).textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Text(
                          '${_relative(huddle.lastActive)} · $members member${members == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: PiColors.of(context).textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(
                    height: 48,
                    width: 24,
                    child: Icon(Icons.chevron_right_rounded)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrandRow extends StatelessWidget {
  final responses.OfficeErrand errand;
  final String coworkerName;
  final VoidCallback? onTap;
  const _ErrandRow({
    required this.errand,
    required this.coworkerName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(errand.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  StatusChip(label: coworkerName, variant: ChipVariant.muted),
                ],
              ),
              if (errand.prompt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(errand.prompt,
                    style: TextStyle(
                        fontSize: 13, color: PiColors.of(context).textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              if (errand.scheduleLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(errand.scheduleLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: PiFonts.mono,
                        color: PiColors.of(context).textFaint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OfficeHuddleScreen extends ConsumerStatefulWidget {
  final String hostId;
  final String? huddleId;
  const OfficeHuddleScreen({super.key, required this.hostId, this.huddleId});

  @override
  ConsumerState<OfficeHuddleScreen> createState() => _OfficeHuddleScreenState();
}

typedef HuddleScreen = OfficeHuddleScreen;
typedef HuddleView = OfficeHuddleScreen;
typedef HuddlePage = OfficeHuddleScreen;

class _OfficeHuddleScreenState extends ConsumerState<OfficeHuddleScreen> {
  final TextEditingController _composer = TextEditingController();
  bool _loading = true;

  String get _huddleId =>
      widget.huddleId ?? ref.read(officeHuddleProvider)?.huddleId ?? '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final id = widget.huddleId;
    if (id != null && id.isNotEmpty) {
      try {
        await ref
            .read(sessionControllerProvider(widget.hostId).notifier)
            .openHuddle(id);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _composer.dispose();
    try {
      ref.read(officeHuddleProvider.notifier).clear();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionControllerProvider(widget.hostId));
    final snap = ref.watch(officeSnapshotProvider);
    final payload = ref.watch(officeHuddleProvider);
    final working = payload?.working ?? const <String, bool>{};
    final isWorking = working.values.any((v) => v);
    final messages = payload?.messages ?? const <Map<String, dynamic>>[];
    final title = payload?.huddleId ?? widget.huddleId ?? 'Huddle';

    return Scaffold(
      appBar: AppBar(
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop()),
        ),
        title: Text(title),
        actions: [
          Semantics(
            label: 'Stop huddle',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _huddleId.isEmpty
                  ? null
                  : () => ref
                      .read(sessionControllerProvider(widget.hostId).notifier)
                      .stopHuddle(_huddleId),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isWorking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: PiColors.accent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('Working…',
                      style: TextStyle(
                          fontSize: 12,
                          color: PiColors.of(context).textSecondary)),
                ],
              ),
            ),
          Expanded(
            child: _loading && payload == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                        message: messages[i],
                        rosterName: (id) => _nameFor(snap, id)),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Message…',
                          border: OutlineInputBorder(),
                          isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                    label: 'Send message',
                    button: true,
                    child: SizedBox(
                      height: 48,
                      width: 48,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () {
                          final text = _composer.text.trim();
                          if (text.isEmpty || _huddleId.isEmpty) return;
                          ref
                              .read(sessionControllerProvider(widget.hostId)
                                  .notifier)
                              .sendToHuddle(_huddleId, text);
                          _composer.clear();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _nameFor(responses.OfficeSnapshot snap, String id) {
    for (final c in snap.coworkers) {
      if (c.id == id) return c.name;
    }
    return id;
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String Function(String id) rosterName;
  const _MessageBubble({required this.message, required this.rosterName});

  @override
  Widget build(BuildContext context) {
    final text = _extractText(message);
    final author = _extractAuthor(message, rosterName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  static String _extractText(Map<String, dynamic> m) {
    final direct = m['text'] ?? m['content'] ?? m['message'] ?? m['body'];
    if (direct is String) return direct;
    if (direct is List) {
      final parts = <String>[];
      for (final item in direct) {
        if (item is Map) {
          final t = item['text'] ?? item['content'];
          if (t is String) parts.add(t);
          if (t is List) {
            parts.addAll(t.whereType<String>());
          }
        } else if (item is String) {
          parts.add(item);
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    final parts = m['parts'];
    if (parts is List) {
      final out = <String>[];
      for (final p in parts) {
        if (p is Map) {
          final t = p['text'];
          if (t is String) out.add(t);
        } else if (p is String) {
          out.add(p);
        }
      }
      if (out.isNotEmpty) return out.join('\n');
    }
    return '';
  }

  static String _extractAuthor(
      Map<String, dynamic> m, String Function(String) rosterName) {
    final candidate =
        m['coworkerId'] ?? m['author'] ?? m['name'] ?? m['role'] ?? m['from'];
    if (candidate == null) return 'Unknown';
    final s = candidate.toString();
    if (s == 'user' || s == 'human' || s == 'you') return 'You';
    if (s == 'assistant' || s == 'agent' || s == 'model') return 'Assistant';
    final resolved = rosterName(s);
    if (resolved != s) return resolved;
    return s;
  }
}

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
