// lib/features/chat/screens/chat_screen.dart
/// The core screen — chat transcript + approvals + composer (doc 06 §3).
/// Layout: App bar → Transcript → Approval bar → Queue card → Status strip →
/// Composer. Desktop-parity UI: one cohesive composer vessel, floating slash
/// palette, status strip where the desktop's StatusBar lives.
///
/// Fully wired: reads chatStateProvider (fed by the event router via
/// SessionController) and sends commands through the session controller.

import 'dart:async' show Timer;
import 'dart:convert' show base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/connection/connection_state.dart' as cs;
import '../../../core/protocol/events.dart' as proto;
import '../../../design/components/banner.dart';
import '../../../design/components/chip.dart';
import '../../../design/theme.dart';
import '../../../features/tools/tool_card.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/markdown_cache.dart';
import '../providers/event_router.dart' as er;

class ChatScreen extends ConsumerStatefulWidget {
  final String hostId;
  final String? sessionPath;

  const ChatScreen({super.key, required this.hostId, this.sessionPath});

  @override ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with AutomaticKeepAliveClientMixin {
  final _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _atBottom = true;
  int _unreadCount = 0;
  int _lastMessageCount = 0;
  String _sendMode = 'prompt'; // prompt | followUp (steer is implicit while streaming)
  final List<XFile> _attachedImages = [];
  String? _draftSession; // sessionFile this draft belongs to
  Timer? _draftSaveTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _composerController.addListener(_onDraftChanged);
    // Desktop parity (open-session.ts): opening a specific session first
    // SWITCHES the engine to it, then reloads. Without the switch we would
    // fetch history for whatever session the engine currently has active.
    Future.microtask(() async {
      final controller = ref.read(sessionControllerProvider(widget.hostId).notifier);
      try {
        final target = widget.sessionPath;
        final current = ref.read(chatStateProvider).session.sessionFile;
        if (target != null && target.isNotEmpty && target != current) {
          await controller.switchSession(target);
        } else {
          await controller.reload();
        }
      } catch (_) {
        // Not connected yet — the resync after connect covers it.
      }
    });
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Per-session draft isolation (desktop draft-store parity): half-written
  /// messages are saved per session and restored on switch — never leak.
  Future<void> _migrateDraft(String? sessionFile) async {
    if (sessionFile == _draftSession) return;
    final prefs = await SharedPreferences.getInstance();
    if (_draftSession != null) {
      await prefs.setString('draft_$_draftSession', _composerController.text);
    }
    _draftSession = sessionFile;
    final restored = sessionFile != null ? prefs.getString('draft_$sessionFile') ?? '' : '';
    if (mounted && _composerController.text != restored) {
      _composerController.text = restored;
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.offset <= 8;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
    if (atBottom && _unreadCount != 0) {
      setState(() => _unreadCount = 0);
    }
  }

  void _onDraftChanged() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_draftSession == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_$_draftSession', _composerController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chat = ref.watch(chatStateProvider);
    final conn = ref.watch(sessionControllerProvider(widget.hostId));
    final agents = ref.watch(subagentsProvider);
    final stats = ref.watch(sessionStatsProvider);
    final sessionName = chat.session.sessionName.isNotEmpty
        ? chat.session.sessionName
        : (widget.sessionPath?.split('/').last ?? 'Session');
    final cwd = chat.session.cwd;

    // Draft migration runs per session (after get_state names the file).
    _migrateDraft(chat.session.sessionFile.isEmpty ? null : chat.session.sessionFile);

    // Auto-scroll only when the user is already at the bottom; otherwise keep
    // a stack of unread messages and offer a JumpToLatestPill.
    final messageCount = chat.messages.length;
    if (messageCount != _lastMessageCount) {
      final delta = messageCount - _lastMessageCount;
      if (_atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      } else if (delta > 0) {
        _unreadCount += delta;
      }
      _lastMessageCount = messageCount;
    }

    return Scaffold(
      appBar: _buildAppBar(sessionName, cwd, chat),
      body: Column(
        children: [
          // ─── Banner (connection/compaction/retry) ─────────────
          if (chat.isRetrying)
            ConnectionBanner(
              type: BannerType.retrying,
              message: chat.retryMax > 0
                  ? 'Retrying (attempt ${chat.retryAttempt}/${chat.retryMax})…'
                  : 'Retrying…',
            )
          else if (chat.session.isCompacting)
            const ConnectionBanner(type: BannerType.compaction, message: 'Compacting context…')
          else if (conn.connection.isResyncing)
            const ConnectionBanner(type: BannerType.reconnecting, message: 'Reconnected — syncing…')
          else if (conn.connection.state == cs.ConnectionState.reconnecting)
            ConnectionBanner(
              type: BannerType.reconnecting,
              message: 'Reconnecting… (attempt ${conn.connection.reconnectAttempt})',
            )
          else if (conn.connection.state == cs.ConnectionState.shuttingDown)
            const ConnectionBanner(type: BannerType.reconnecting, message: 'Bridge shutting down…'),

          // ─── Transcript ───────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(sessionControllerProvider(widget.hostId).notifier).reload();
                } catch (_) {}
              },
              child: _buildTranscript(chat, conn),
            ),
          ),

          // ─── UI request card (approvals, questions, selects, inputs, notify) ──
          if (chat.approvals.isNotEmpty) ...[
            _UiRequestCard(
              key: ValueKey(chat.approvals.values.first.id),
              request: chat.approvals.values.first,
              controller: ref.read(sessionControllerProvider(widget.hostId).notifier),
            ),
            const SizedBox(height: 4),
          ],

          // ─── Queue card (when non-empty) ──────────────────────
          if (chat.queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _QueuedCard(
                queue: chat.queue,
                onRemove: (kind, index) => ref
                    .read(sessionControllerProvider(widget.hostId).notifier)
                    .removeQueueItem(kind, index),
                onRestore: () async {
                  // Desktop Esc-to-dequeue: dequeue everything into the composer.
                  if (_hapticsOn) HapticFeedback.selectionClick();
                  try {
                    final removed = await ref
                        .read(sessionControllerProvider(widget.hostId).notifier)
                        .clearQueue();
                    final text = [...removed.steering, ...removed.followUp].join('\n\n');
                    if (text.isNotEmpty && mounted) {
                      _composerController.text = _composerController.text.isEmpty
                          ? text
                          : '${_composerController.text}\n\n$text';
                    }
                  } catch (_) {}
                },
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ─── Status strip (desktop StatusBar parity) ──────────
          _buildStatusStrip(chat, agents, stats),

          // ─── Composer ─────────────────────────────────────────
          _buildComposer(chat),
        ],
      ),
    );
  }

  // ─── App bar (slim — desktop IA: chrome lives in the status strip) ──
  PreferredSizeWidget _buildAppBar(String sessionName, String cwd, er.ChatState chat) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sessionName, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (cwd.isNotEmpty)
            Text(cwd, style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_comment_outlined, size: 20),
          tooltip: 'New session',
          onPressed: () async {
            final controller = ref.read(sessionControllerProvider(widget.hostId).notifier);
            try {
              await controller.newSession();
              if (mounted) Navigator.of(context).pop();
            } catch (_) {
              // Not connected — stay put; the banner explains why.
            }
          },
        ),
        PopupMenuButton<String>(
          onSelected: (val) => _onMenuAction(val, chat),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'compact', child: Text('Compact Context')),
            PopupMenuItem(value: 'export', child: Text('Export HTML')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'copy', child: Text('Copy Transcript')),
          ],
        ),
      ],
    );
  }

  void _onMenuAction(String val, er.ChatState chat) async {
    final controller = ref.read(sessionControllerProvider(widget.hostId).notifier);
    switch (val) {
      case 'compact':
        await controller.compact();
      case 'export':
        try {
          final path = await controller.exportHtml(chat.session.sessionFile.isNotEmpty
              ? chat.session.sessionFile
              : (widget.sessionPath ?? ''));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported: ${path ?? 'done'}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export failed')),
            );
          }
        }
      case 'copy':
        final text = chat.messages.map((m) => _plainText(m)).where((t) => t.isNotEmpty).join('\n\n');
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied ${chat.messages.length} messages')),
          );
        }
    }
  }

  // ─── Transcript ────────────────────────────────────────────────
  Widget _buildTranscript(er.ChatState chat, SessionControllerState conn) {
    final loading = conn.connection.isResyncing || conn.starting;
    if (chat.messages.isEmpty) {
      if (loading) {
        // Skeleton rows while history loads (session.messageCount gives density).
        final n = chat.session.messageCount.clamp(3, 8);
        return ListView.builder(
          reverse: true,
          itemCount: n,
          itemBuilder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: PiColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PiColors.border),
              ),
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 40, color: PiColors.textFaint),
            const SizedBox(height: 12),
            Text('Send a task to get started', style: TextStyle(color: PiColors.textMuted)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          reverse: true,
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Reversed list: index 0 is the newest message.
                  final message = chat.messages[chat.messages.length - 1 - index];
                  return RepaintBoundary(
                    child: _MessageView(message: message, toolCards: chat.toolCards),
                  );
                },
                childCount: chat.messages.length,
              ),
            ),
          ],
        ),
        if (!_atBottom)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _JumpToLatestPill(
                unreadCount: _unreadCount,
                onTap: () {
                  setState(() => _atBottom = true);
                  if (_scrollController.hasClients) _scrollController.jumpTo(0);
                },
              ),
            ),
          ),
      ],
    );
  }

  // ─── Status strip (desktop StatusBar parity) ───────────────────
  /// model · thinking · permission · subagents · context % · turn usage —
  /// one slim, horizontally scrollable strip directly above the composer
  /// (desktop renders its StatusBar at window bottom).
  Widget _buildStatusStrip(er.ChatState chat, List<proto.SubAgentRecord> agents, SessionStats stats) {
    final session = chat.session;
    final runningAgents = agents.where((a) => a.status == 'running').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PiColors.surfaceRaised,
        border: Border(top: BorderSide(color: PiColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (session.model.isNotEmpty) ...[
              StatusChip(
                label: session.modelName.isNotEmpty ? session.modelName : session.model,
                variant: ChipVariant.accent,
                onTap: _showModelPicker,
              ),
              const SizedBox(width: 6),
            ],
            StatusChip(
              label: session.thinkingLevel == 'off' ? 'thinking off' : session.thinkingLevel,
              variant: ChipVariant.muted,
              onTap: _showThinkingSheet,
            ),
            const SizedBox(width: 6),
            StatusChip(
              label: session.permissionMode,
              variant: ChipVariant.tool,
              onTap: _showPermissionModeSheet,
            ),
            if (agents.isNotEmpty) ...[
              const SizedBox(width: 6),
              StatusChip(
                label: '$runningAgents agents',
                variant: ChipVariant.tool,
                onTap: () => _showSubagentsSheet(agents),
              ),
            ],
            if (stats.hasData && stats.percent != null) ...[
              const SizedBox(width: 6),
              Text(
                '${stats.percent!.round()}% ctx',
                style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: PiColors.textMuted),
              ),
            ],
            if (chat.lastUsage != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatUsage(chat.lastUsage!),
                style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: PiColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Composer (desktop Composer.tsx parity) ────────────────────
  /// ONE rounded glass vessel: text field inside, attach + mode + send on its
  /// bottom row, attachment chips inside the top, slash palette floating
  /// above as an overlay card.
  Widget _buildComposer(er.ChatState chat) {
    final isStreaming = chat.isStreaming || chat.session.isStreaming;
    final commands = ref.watch(slashCommandsProvider);
    final slashSuggestions = _slashMatches(commands);
    final canSend = _composerController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Slash-command palette — floating overlay card above the field
          // (desktop CommandPalette parity), not an inline section.
          if (slashSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: PiColors.of(context).surfaceOverlay,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PiColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final cmd in slashSuggestions)
                    InkWell(
                      onTap: () {
                        _composerController.text = '/${cmd['name']} ';
                        _composerController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _composerController.text.length));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('/${cmd['name']}',
                                style: const TextStyle(
                                    fontSize: 13, fontFamily: 'JetBrains Mono', color: PiColors.accent)),
                            if (cmd['description'] is String)
                              Text(cmd['description'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: PiColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── The composer vessel ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: PiColors.of(context).surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PiColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Attachment chips — compact "Image N ×" (desktop style)
                if (_attachedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _attachedImages.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: PiColors.textFaint.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PiColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 13, color: PiColors.textMuted),
                                const SizedBox(width: 6),
                                Text('Image ${i + 1}',
                                    style: const TextStyle(fontSize: 11, color: PiColors.textSecondary)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(() => _attachedImages.removeAt(i)),
                                  child: const Icon(Icons.close, size: 12, color: PiColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // Text field — borderless inside the vessel, auto-grows
                TextField(
                  controller: _composerController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14.5, height: 1.4, color: PiColors.text),
                  decoration: InputDecoration(
                    hintText: isStreaming
                        ? 'Steer the agent…'
                        : 'Ask A-Coder anything — type / for commands',
                    hintStyle: const TextStyle(fontSize: 14.5, color: PiColors.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                // Bottom row: attach · mode · send — all inside the vessel
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                      onPressed: _pickImages,
                      color: PiColors.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Attach images',
                    ),

                    if (!isStreaming) ...[
                      const SizedBox(width: 2),
                      // Mode selector — compact segmented control
                      Container(
                        decoration: BoxDecoration(
                          color: PiColors.textFaint.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeSegment(
                              label: 'Send',
                              selected: _sendMode == 'prompt',
                              onTap: () => setState(() => _sendMode = 'prompt'),
                            ),
                            _ModeSegment(
                              label: 'Queue',
                              selected: _sendMode == 'followUp',
                              onTap: () => setState(() => _sendMode = 'followUp'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 2),
                      const Text('STEERING',
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'JetBrains Mono',
                              letterSpacing: 0.5,
                              color: PiColors.accent)),
                    ],

                    const Spacer(),

                    // Send / Stop — compact filled circle at the right edge
                    if (isStreaming)
                      _ComposerButton(
                        icon: Icons.stop_rounded,
                        color: PiColors.error,
                        tooltip: 'Abort turn',
                        onTap: () => ref.read(sessionControllerProvider(widget.hostId).notifier).abort(),
                      )
                    else
                      _ComposerButton(
                        icon: Icons.keyboard_return_rounded,
                        color: canSend ? PiColors.accent : PiColors.textFaint,
                        enabled: canSend,
                        tooltip: 'Send',
                        onTap: () {
                          if (_hapticsOn) HapticFeedback.lightImpact();
                          _submit(isStreaming);
                        },
                      ),
                  ],
                ),

                // Streaming indicator — typing dots inside the vessel
                if (isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _TypingDot(delay: Duration(milliseconds: 0)),
                        _TypingDot(delay: Duration(milliseconds: 200)),
                        _TypingDot(delay: Duration(milliseconds: 400)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _hapticsOn => ref.read(settingsProvider).haptics;

  /// Composer autocomplete candidates: '/' prefix, no space typed yet.
  List<Map<String, dynamic>> _slashMatches(List<Map<String, dynamic>> all) {
    final text = _composerController.text;
    if (!text.startsWith('/') || text.contains(' ')) return const [];
    final q = text.substring(1).toLowerCase();
    return all.where((c) => (c['name'] as String? ?? '').toLowerCase().startsWith(q)).take(5).toList();
  }

  void _submit(bool isStreaming) async {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    _composerController.clear();
    final images = List<XFile>.from(_attachedImages);
    _attachedImages.clear();
    if (mounted) setState(() {});
    try {
      await ref.read(sessionControllerProvider(widget.hostId).notifier).sendPrompt(
            text,
            mode: isStreaming ? 'steer' : _sendMode,
            images: [
              for (final img in images)
                {
                  'type': 'image',
                  'data': base64Encode(await img.readAsBytes()),
                  'mimeType': img.mimeType ?? _mimeTypeFromPath(img.path),
                },
            ],
          );
      if (_hapticsOn) HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Send failed: not connected')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _attachedImages.addAll(picked));
  }

  String _mimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  void _showSubagentsSheet(List<proto.SubAgentRecord> agents) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Subagents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (agents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No subagents', style: TextStyle(fontSize: 13, color: PiColors.textMuted)),
              ),
            for (final a in agents)
              ListTile(
                dense: true,
                leading: Icon(
                  a.status == 'running'
                      ? Icons.pending_rounded
                      : (a.status == 'failed' ? Icons.error_outline : Icons.check_circle_outline),
                  size: 16,
                  color: a.status == 'running'
                      ? PiColors.accent
                      : (a.status == 'failed' ? PiColors.error : PiColors.success),
                ),
                title: Text(a.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                trailing: Text(a.status,
                    style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
              ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker() {
    Navigator.of(context).pushNamed('/model');
  }

  void _showThinkingSheet() {
    final controller = ref.read(sessionControllerProvider(widget.hostId).notifier);
    final current = ref.read(chatStateProvider).session.thinkingLevel;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Thinking Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final level in const ['off', 'minimal', 'low', 'medium', 'high'])
              ListTile(
                title: Text(level),
                trailing: level == current ? const Icon(Icons.check_rounded, color: PiColors.accent) : null,
                onTap: () {
                  controller.setThinkingLevel(level);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPermissionModeSheet() {
    final controller = ref.read(sessionControllerProvider(widget.hostId).notifier);
    final current = ref.read(chatStateProvider).session.permissionMode;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Permission Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final mode in const [
              ('default', 'Engine default behavior'),
              ('plan', 'Ask before running tools'),
              ('auto', 'Run tools automatically'),
            ])
              ListTile(
                title: Text(mode.$1),
                subtitle: Text(mode.$2, style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
                trailing: mode.$1 == current ? const Icon(Icons.check_rounded, color: PiColors.accent) : null,
                onTap: () {
                  controller.setPermissionMode(mode.$1);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Message rendering (parses the raw protocol message lazily) ──

class _MessageView extends StatelessWidget {
  final er.UiMessage message;
  final Map<String, er.ToolCardState> toolCards;

  const _MessageView({required this.message, required this.toolCards});

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final parts = content is Map<String, dynamic> && content['content'] is List<dynamic>
        ? (content['content'] as List<dynamic>).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    switch (message.role) {
      case 'user':
        return _UserMessageBubble(text: _textOf(parts));
      case 'toolResult':
        return _ToolResultView(message: message, parts: parts);
      case 'assistant':
        return _AssistantView(message: message, parts: parts, toolCards: toolCards);
      default:
        return const SizedBox.shrink();
    }
  }

  static String _textOf(List<Map<String, dynamic>> parts) {
    return parts
        .where((p) => p['type'] == 'text' && p['text'] is String)
        .map((p) => p['text'] as String)
        .join('\n');
  }
}

class _UserMessageBubble extends StatelessWidget {
  final String text;
  const _UserMessageBubble({required this.text});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: () => Clipboard.setData(ClipboardData(text: text)),
          child: Semantics(
            label: text,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PiColors.userBubble.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(maxWidth: 300, minHeight: 48),
              child: Text(text, style: const TextStyle(fontSize: 14, color: PiColors.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantView extends StatelessWidget {
  final er.UiMessage message;
  final List<Map<String, dynamic>> parts;
  final Map<String, er.ToolCardState> toolCards;

  const _AssistantView({required this.message, required this.parts, required this.toolCards});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interleave content parts in order: thinking / text / toolCall.
          for (final part in parts) ...[
            if (part['type'] == 'thinking' && part['thinking'] is String)
              _ThinkingBlock(thinking: part['thinking'] as String),
            if (part['type'] == 'text' && part['text'] is String)
              _MarkdownContent(messageId: message.id, data: part['text'] as String),
            if (part['type'] == 'toolCall')
              _InlineToolCall(
                callId: part['id'] as String? ?? '',
                toolName: part['name'] as String? ?? 'tool',
                args: part['arguments'] is Map<String, dynamic> ? part['arguments'] as Map<String, dynamic> : const {},
                card: toolCards[part['id']],
              ),
          ],

          // Typing indicator while this message streams.
          if (message.isStreaming)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(children: [_TypingDot(delay: Duration(milliseconds: 0))]),
            ),
        ],
      ),
    );
  }
}

/// A toolCall part inside an assistant message — renders the shared ToolCard
/// with live state from toolCards (partial results, errors) when present.
class _InlineToolCall extends StatelessWidget {
  final String callId;
  final String toolName;
  final Map<String, dynamic> args;
  final er.ToolCardState? card;

  const _InlineToolCall({required this.callId, required this.toolName, required this.args, this.card});

  @override Widget build(BuildContext context) {
    if (callId.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ToolCard(
        key: ValueKey(callId),
        toolName: toolName,
        args: args,
        result: card?.result,
        partialResult: card?.partialResult,
        isComplete: card?.isComplete ?? false,
        isError: card?.isError ?? false,
      ),
    );
  }
}

class _ToolResultView extends StatelessWidget {
  final er.UiMessage message;
  final List<Map<String, dynamic>> parts;

  const _ToolResultView({required this.message, required this.parts});

  @override Widget build(BuildContext context) {
    final isError = message.content is Map<String, dynamic> && (message.content as Map<String, dynamic>)['isError'] == true;
    final text = _MessageView._textOf(parts);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isError ? PiColors.error : PiColors.success).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isError ? PiColors.error : PiColors.success).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? PiColors.error : PiColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? 'Tool result' : text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownContent extends ConsumerWidget {
  final String messageId;
  final String data;
  const _MarkdownContent({required this.messageId, required this.data});

  @override Widget build(BuildContext context, WidgetRef ref) {
    // Chat text size is a user setting (doc 06 §5; desktop SettingsPanel).
    final scale = ref.watch(settingsProvider.select((s) => s.chatTextSize)) / 14.0;
    // Keep parsed markdown cached keyed by (messageId, contentLength) so
    // message_update never renders stale content.
    markdownBlockCache.get<List<dynamic>>(messageId, data.length) ??
        markdownBlockCache.put(messageId, data.length, data);
    double fs(double v) => v * scale;
    return MarkdownBody(
      data: data,
      softLineBreak: true,
      builders: {
        // Horizontal-scroll code blocks — desktop doesn't clip long lines.
        'pre': _CodeBlockBuilder(fontSize: fs(13)),
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: fs(14), height: 1.5, color: PiColors.text),
        h1: TextStyle(fontSize: fs(18), fontWeight: FontWeight.w600, color: PiColors.text),
        h2: TextStyle(fontSize: fs(16), fontWeight: FontWeight.w600, color: PiColors.text),
        h3: TextStyle(fontSize: fs(15), fontWeight: FontWeight.w600, color: PiColors.text),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        em: const TextStyle(fontStyle: FontStyle.italic),
        code: TextStyle(fontSize: fs(13), fontFamily: 'JetBrains Mono', color: PiColors.accent, backgroundColor: PiColors.surfaceRaised),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF0A0A0C), // code blocks stay dark (desktop parity)
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PiColors.border),
        ),
        blockquote: TextStyle(fontSize: fs(14), color: PiColors.textSecondary),
        listBullet: TextStyle(fontSize: fs(14), color: PiColors.text),
      ),
    );
  }
}

/// Fenced code blocks scroll horizontally instead of clipping long lines.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  final double fontSize;
  _CodeBlockBuilder({required this.fontSize});

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final code = element.textContent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PiColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: TextStyle(fontSize: fontSize, fontFamily: 'JetBrains Mono', height: 1.45, color: PiColors.text),
        ),
      ),
    );
  }
}

class _ThinkingBlock extends StatefulWidget {
  final String thinking;
  const _ThinkingBlock({required this.thinking});

  @override State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PiColors.textFaint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_expanded ? '▾' : '▸', style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
                const SizedBox(width: 4),
                const Text('Thinking',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: PiColors.textMuted)),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 4),
              Text(widget.thinking, style: const TextStyle(fontSize: 12, color: PiColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;
  const _TypingDot({required this.delay});

  @override State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
    _controller.repeat(reverse: true);
  }

  @override void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(color: PiColors.accent, shape: BoxShape.circle));
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Opacity(
        opacity: _animation.value,
        child: Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(color: PiColors.accent, shape: BoxShape.circle)),
      ),
    );
  }
}

// ─── UI request cards (doc 06 §4.2, doc 03 §4.5) ─────────────
/// One card per extension_ui_request method:
///   confirm(kind: permission) → swipe-to-allow + deny + always-allow
///   confirm (other)           → allow / deny
///   question                  → tappable options → {answers: Record<header, answer>}
///   select                    → single/multi choice → {value: string}
///   input / editor            → text field → {value: string}
///   notify                    → toast-style card, acknowledges on dismiss
class _UiRequestCard extends ConsumerStatefulWidget {
  final er.UiRequest request;
  final SessionController controller;

  const _UiRequestCard({super.key, required this.request, required this.controller});

  @override ConsumerState<_UiRequestCard> createState() => _UiRequestCardState();
}

class _UiRequestCardState extends ConsumerState<_UiRequestCard> {
  double _dragExtent = 0.0; // swipe-to-approve progress
  final _inputController = TextEditingController();
  final Map<String, bool> _checked = {}; // multi-select state
  bool _responding = false;
  int? _remaining;
  DateTime? _expiry;
  Timer? _expiryTimer;

  @override void initState() {
    super.initState();
    _startCountdown(widget.request);
  }

  @override void didUpdateWidget(covariant _UiRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id || oldWidget.request.timeout != widget.request.timeout) {
      _expiryTimer?.cancel();
      _responding = false;
      _startCountdown(widget.request);
    }
  }

  void _startCountdown(er.UiRequest request) {
    final timeout = request.timeout;
    if (timeout == null || timeout <= 0) return;
    _expiry = DateTime.now().add(Duration(seconds: timeout));
    _remaining = timeout;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final rem = _expiry!.difference(DateTime.now()).inSeconds;
      if (rem <= 0) {
        timer.cancel();
        if (mounted) setState(() => _remaining = 0);
        if (!_responding) {
          widget.controller.cancelUiRequest(request);
        }
      } else {
        setState(() => _remaining = rem);
      }
    });
  }

  @override void dispose() {
    _expiryTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _haptic() {
    if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
  }

  void _beginRespond() {
    if (_responding) return;
    setState(() => _responding = true);
  }

  @override Widget build(BuildContext context) {
    final request = widget.request;
    final header = request.title ?? request.toolName ?? 'Agent needs your input';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PiColors.warning.withValues(alpha: request.method == 'notify' ? 0.05 : 0.08),
        border: Border(top: BorderSide(color: PiColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (request.method) {
                  'confirm' => Icons.security_rounded,
                  'question' => Icons.help_outline_rounded,
                  'select' => Icons.checklist_rounded,
                  'input' || 'editor' => Icons.keyboard_rounded,
                  _ => Icons.info_outline_rounded,
                },
                size: 16,
                color: PiColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
              ),
              if (widget.request.timeout != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${_remaining ?? widget.request.timeout}s',
                    style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: PiColors.textMuted),
                  ),
                ),
              // Dismiss = engine default/timeout resolution.
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: PiColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.controller.cancelUiRequest(request);
                },
              ),
            ],
          ),

          if (request.toolName != null && request.message != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(request.toolName!,
                  style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500)),
            ),
          ],
          if (request.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(request.message!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
            ),

          ..._buildMethodBody(request),
        ],
      ),
    );
  }

  List<Widget> _buildMethodBody(er.UiRequest request) {
    switch (request.method) {
      case 'confirm':
        return _buildConfirmBody(request);
      case 'question':
        return _buildOptionList(request, onPick: (label) {
          if (_responding) return;
          _haptic();
          _beginRespond();
          widget.controller.respondQuestion(request, label);
        });
      case 'select':
        return _buildSelectBody(request);
      case 'input':
      case 'editor':
        return _buildInputBody(request);
      case 'notify':
        return [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => widget.controller.cancelUiRequest(request),
              child: const Text('Got it'),
            ),
          ),
        ];
      default:
        // Unknown method — allow a plain confirm/cancel (forward-compat).
        return [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.controller.cancelUiRequest(request),
                  child: const Text('Dismiss'),
                ),
              ),
            ]),
          ),
        ];
    }
  }

  // ── confirm: swipe-to-allow slider + deny + always-allow ──
  List<Widget> _buildConfirmBody(er.UiRequest request) {
    final isPermission = request.kind == 'permission';
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (isPermission)
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(() {
                    _dragExtent = (_dragExtent + d.delta.distance / 200).clamp(0.0, 1.0);
                  }),
                  onHorizontalDragEnd: (d) {
                    if (!_responding && _dragExtent > 0.7) {
                      _haptic();
                      _beginRespond();
                      widget.controller.respondApproval(request, 'allow');
                    }
                    setState(() => _dragExtent = 0.0);
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: PiColors.warning.withValues(alpha: 0.15 + 0.2 * _dragExtent),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: PiColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swipe_right_rounded, size: 16, color: PiColors.warning),
                          SizedBox(width: 6),
                          Text('Swipe to allow',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.warning)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _responding
                      ? null
                      : () {
                          _haptic();
                          _beginRespond();
                          widget.controller.respondApproval(request, 'allow');
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: PiColors.warning),
                  child: const Text('Allow'),
                ),
              ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _responding
                  ? null
                  : () {
                      _haptic();
                      _beginRespond();
                      widget.controller.respondApproval(request, 'deny');
                    },
              style: OutlinedButton.styleFrom(
                  foregroundColor: PiColors.error,
                  side: BorderSide(color: PiColors.error.withValues(alpha: 0.3))),
              child: const Text('Deny'),
            ),
            if (isPermission) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _responding
                    ? null
                    : () {
                        _haptic();
                        _beginRespond();
                        widget.controller.respondApproval(request, 'always_allow');
                      },
                child: const Text('Always'),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ── question: tappable option rows ──
  List<Widget> _buildOptionList(er.UiRequest request, {required ValueChanged<String> onPick}) {
    final options = request.options ?? const [];
    return [
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            onTap: () => onPick(option['label'] as String? ?? ''),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: PiColors.textFaint.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PiColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option['label'] as String? ?? '',
                      style: const TextStyle(fontSize: 13, color: PiColors.text)),
                  if (option['description'] is String)
                    Text(option['description'] as String,
                        style: const TextStyle(fontSize: 11, color: PiColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  // ── select: single tap or multi-select checkboxes + submit ──
  List<Widget> _buildSelectBody(er.UiRequest request) {
    final options = request.options ?? const [];
    final multi = request.multiSelect ?? false;

    if (!multi) {
      return _buildOptionList(request, onPick: (label) {
        if (_responding) return;
        _haptic();
        _beginRespond();
        widget.controller.respondSelect(request, [label]);
      });
    }

    return [
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _MultiSelectRow(
            label: option['label'] as String? ?? '',
            value: _checked[option['label'] as String? ?? ''] ?? false,
            onToggled: (v) => setState(() => _checked[option['label'] as String? ?? ''] = v),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ElevatedButton(
          onPressed: _responding
              ? null
              : () {
                  _haptic();
                  _beginRespond();
                  widget.controller.respondSelect(request, _checkedValues(request));
                },
          child: const Text('Submit'),
        ),
      ),
    ];
  }

  List<String> _checkedValues(er.UiRequest request) {
    return (request.options ?? const [])
        .map((o) => o['label'] as String? ?? '')
        .where((label) => _checked[label] ?? false)
        .toList();
  }

  // ── input / editor: text field + submit ──
  List<Widget> _buildInputBody(er.UiRequest request) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: request.title ?? 'Type your answer…',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _responding
                  ? null
                  : () {
                      _haptic();
                      _beginRespond();
                      widget.controller.respondInput(request, _inputController.text.trim());
                    },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Checkbox row for multi-select (state lifted into _UiRequestCardState._checked).
class _MultiSelectRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onToggled;

  const _MultiSelectRow({required this.label, required this.value, required this.onToggled});

  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PiColors.border),
      ),
      child: CheckboxListTile(
        dense: true,
        value: value,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        onChanged: (v) => onToggled(v ?? false),
      ),
    );
  }
}

// ─── Queue card (doc 06 §3) ──────────────────────────────────

class _QueuedCard extends StatelessWidget {
  final er.QueueState queue;
  final void Function(String kind, int index) onRemove;
  final VoidCallback onRestore;

  const _QueuedCard({required this.queue, required this.onRemove, required this.onRestore});

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: PiColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.queue_play_next_rounded, size: 14, color: PiColors.accent),
              const SizedBox(width: 4),
              Text('Queued ${queue.steering.length + queue.followUp.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < queue.steering.length; i++)
            _QueueItem(label: queue.steering[i], type: QueueItemType.steering, onRemove: () => onRemove('steering', i)),
          for (var i = 0; i < queue.followUp.length; i++)
            _QueueItem(
                label: queue.followUp[i], type: QueueItemType.followUp, onRemove: () => onRemove('followUp', i)),
          const SizedBox(height: 4),
          InkWell(
            onTap: onRestore,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Restore to composer',
                  style: TextStyle(
                      fontSize: 12, color: PiColors.accent, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}

enum QueueItemType { steering, followUp }

class _QueueItem extends StatelessWidget {
  final String label;
  final QueueItemType type;
  final VoidCallback onRemove;

  const _QueueItem({required this.label, required this.type, required this.onRemove});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            type == QueueItemType.steering ? Icons.bolt_rounded : Icons.schedule_send_rounded,
            size: 14,
            color: type == QueueItemType.steering ? PiColors.accent : PiColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
          TextButton(onPressed: onRemove, child: const Text('Remove', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

// ─── Composer building blocks ─────────────────────────────────

/// Compact mode segment inside the composer vessel (desktop segmented style).
class _ModeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSegment({required this.label, required this.selected, required this.onTap});

  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? PiColors.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? PiColors.accent : PiColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Compact filled-circle action button for the composer's right edge
/// (desktop Button size="icon" parity).
class _ComposerButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _ComposerButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: enabled ? color : color.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────

String _formatUsage(proto.UsageData usage) {
  String compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
  final cost = usage.costTotal != null ? ' · \$${usage.costTotal!.toStringAsFixed(2)}' : '';
  return '↑${compact(usage.input + usage.cacheWrite)} ↓${compact(usage.output + usage.cacheRead)}$cost';
}

String _plainText(er.UiMessage m) {
  final content = m.content;
  if (content is! Map<String, dynamic>) return '';
  final parts = content['content'];
  if (parts is! List<dynamic>) return '';
  return parts
      .whereType<Map<String, dynamic>>()
      .where((p) => p['type'] == 'text' && p['text'] is String)
      .map((p) => p['text'] as String)
      .join('\n');
}

class _JumpToLatestPill extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _JumpToLatestPill({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Jump to latest messages${unreadCount > 0 ? ', $unreadCount new' : ''}',
      child: Material(
        color: PiColors.accent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  unreadCount > 0 ? 'Jump to latest ($unreadCount)' : 'Jump to latest',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
