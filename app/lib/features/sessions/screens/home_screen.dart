// lib/features/sessions/screens/home_screen.dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connection/connection_state.dart' as cs;
import '../../../core/connection/feature_flags.dart';
import '../../../core/protocol/responses.dart' show RpcSessionInfo;
import '../../../design/theme.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/status_dot.dart';
import '../../../design/components/chip.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../chat/providers/chat_providers.dart';
import '../providers/sessions_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String activeHostId;
  const HomeScreen({super.key, required this.activeHostId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(sessionControllerProvider(widget.activeHostId).notifier).refreshSessions();
      } catch (_) {
        // Not connected yet — retry via pull-to-refresh.
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearchQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hostAsync = ref.watch(activeHostProvider);
    final sessions = ref.watch(sessionsListProvider);
    final conn = ref.watch(sessionControllerProvider(widget.activeHostId));
    final hostName = hostAsync.valueOrNull?.name ?? 'A-Coder';
    final connected = conn.connection.state == cs.ConnectionState.ready;

    final filtered = _searchQuery.isEmpty
        ? sessions
        : sessions
            .where((s) =>
                (s.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.cwd.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (s.firstMessage ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(hostName),
        actions: [
          IconButton(
            tooltip: 'Connection status',
            icon: Semantics(
              label: 'Connection status',
              child: StatusDot(
                type: switch (conn.connection.state) {
                  cs.ConnectionState.ready => StatusDotType.live,
                  cs.ConnectionState.disconnected => StatusDotType.error,
                  _ => StatusDotType.idle,
                },
                size: 10,
              ),
            ),
            onPressed: () => _showConnectionSheet(context, conn),
          ),
          if (FeatureFlags.enableCron || FeatureFlags.enableOffice)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                final args = {'hostId': widget.activeHostId};
                if (value == 'cron') {
                  Navigator.of(context).pushNamed('/cron', arguments: args);
                } else if (value == 'office') {
                  Navigator.of(context).pushNamed('/office', arguments: args);
                }
              },
              itemBuilder: (_) => [
                if (FeatureFlags.enableCron)
                  const PopupMenuItem(
                      value: 'cron', child: Text('Scheduled tasks')),
                if (FeatureFlags.enableOffice)
                  const PopupMenuItem(value: 'office', child: Text('Your Office')),
              ],
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Consumer(
              builder: (context, ref, _) {
                final chat = ref.watch(chatStateProvider);
                final background = ref.watch(backgroundSessionsProvider);
                return Row(
                  children: [
                    if (chat.isStreaming) ...[
                      const StatusChip(label: '● streaming', variant: ChipVariant.accent),
                      const SizedBox(width: 8),
                    ],
                    if (background.isNotEmpty) ...[
                      StatusChip(
                        label: '${background.length} background',
                        variant: ChipVariant.muted,
                        onTap: () => _showBackgroundSheet(context, background),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (chat.queue.steering.isNotEmpty || chat.queue.followUp.isNotEmpty)
                      StatusChip(
                        label: 'queue ${chat.queue.steering.length + chat.queue.followUp.length}',
                        variant: ChipVariant.tool,
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (q) {
                _setSearchQuery(q);
                if (q.isEmpty) setState(() => _searchQuery = '');
              },
              decoration: InputDecoration(
                hintText: 'Search sessions by name or path…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) setState(() => _searchQuery = '');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (!connected) return;
                try {
                  await ref.read(sessionControllerProvider(widget.activeHostId).notifier).refreshSessions();
                } catch (_) {}
              },
              child: filtered.isEmpty
                  ? _emptyState(context, sessions, connected)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: filtered.length,
                      itemExtent: null,
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        return _SessionRow(
                          key: ValueKey(session.path.isNotEmpty ? session.path : session.id),
                          session: session,
                          connected: connected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pushNamed(
                              '/chat',
                              arguments: {'hostId': widget.activeHostId, 'sessionPath': session.path},
                            );
                          },
                          onRename: () => _renameSession(session),
                          onDelete: () => _confirmDelete(session),
                          onStop: () => ref
                              .read(sessionControllerProvider(widget.activeHostId).notifier)
                              .abortSession(session.path),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        label: 'New session',
        child: FloatingActionButton(
          onPressed: () async {
            final controller = ref.read(sessionControllerProvider(widget.activeHostId).notifier);
            try {
              await controller.newSession();
            } catch (_) {
              // Not connected yet — still open the chat (it will show the banner).
            }
            if (context.mounted) {
              Navigator.of(context).pushNamed(
                '/chat',
                arguments: {'hostId': widget.activeHostId},
              );
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, List<RpcSessionInfo> sessions, bool connected) {
    if (!connected) {
      return const ErrorState(
        message: 'Offline — reconnect to load sessions.',
        onRetry: _noop,
      );
    }
    if (_searchQuery.isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching sessions',
        hint: 'Try a different query.',
      );
    }
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No sessions yet',
        hint: 'Start one from the + button.',
      );
    }
    return const SizedBox.shrink();
  }

  static void _noop() {}

  Future<void> _renameSession(dynamic session) async {
    final controller = ref.read(sessionControllerProvider(widget.activeHostId).notifier);
    final nameController = TextEditingController(text: (session.name as String?) ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename session'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Session name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rename')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previous = (session.name as String?) ?? '';
    final name = nameController.text.trim();
    if (name.isEmpty || name == previous) return;
    try {
      await controller.renameSession(session.path as String, name);
      await controller.refreshSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renamed to "$name"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await controller.renameSession(session.path as String, previous);
              await controller.refreshSessions();
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rename failed — not connected')),
        );
      }
    }
  }

  Future<void> _confirmDelete(dynamic session) async {
    final controller = ref.read(sessionControllerProvider(widget.activeHostId).notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Remove "${(session.name as String?)?.isNotEmpty == true ? session.name : session.id}" from the list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: PiColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // stop if streaming handled by engine; best-effort local remove.
    ref.read(sessionsListProvider.notifier).removeSession(session.path as String);
    try {
      await controller.refreshSessions();
    } catch (_) {}
  }

  void _showConnectionSheet(BuildContext context, SessionControllerState conn) {
    final host = ref.read(activeHostProvider).valueOrNull;
    final url = host?.wsUrl ?? '—';
    final connected = conn.connection.state == cs.ConnectionState.ready;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [StatusDot(type: connected ? StatusDotType.live : StatusDotType.idle, size: 8)]),
              const SizedBox(height: 8),
              Text(
                connected ? 'Connected' : conn.connection.state.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(url, style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
              if (conn.connection.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    conn.connection.errorMessage!,
                    style: const TextStyle(fontSize: 13, color: PiColors.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackgroundSheet(BuildContext context, List<dynamic> sessions) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Background Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                const Text('No background sessions', style: TextStyle(fontSize: 13, color: PiColors.textMuted))
              else
                for (final s in sessions)
                  _BgSessionRow(
                    cwd: s.cwd as String,
                    status: s.status as String,
                    pending: s.pendingMessageCount as int,
                    onOpen: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushNamed(
                        '/chat',
                        arguments: {'hostId': widget.activeHostId, 'sessionPath': s.sessionPath as String?},
                      );
                    },
                    onAbort: () {
                      ref
                          .read(sessionControllerProvider(widget.activeHostId).notifier)
                          .abortSession(s.path);
                      ref.read(backgroundSessionsProvider.notifier).remove(s.path);
                      Navigator.pop(ctx);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final RpcSessionInfo session;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onStop;

  const _SessionRow({
    super.key,
    required this.session,
    required this.connected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final name = (session.name != null && session.name!.isNotEmpty)
        ? session.name!
        : (session.firstMessage ?? session.id);
    final path = session.cwd;
    final msgCount = session.messageCount;
    final modified = DateTime.tryParse(session.modified) ?? DateTime.now();
    return ListTile(
      key: ValueKey(session.path),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(path, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(_relativeTime(modified), style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
              const SizedBox(width: 12),
              Text('$msgCount messages', style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
              if (session.parentSessionPath != null) ...[
                const SizedBox(width: 8),
                const StatusChip(label: 'child', variant: ChipVariant.tool),
              ],
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: PiColors.textFaint),
      onTap: onTap,
      onLongPress: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename'), onTap: () => Navigator.pop(ctx, 'rename')),
                ListTile(leading: const Icon(Icons.stop_circle_outlined), title: const Text('Stop'), onTap: () => Navigator.pop(ctx, 'stop')),
                ListTile(leading: const Icon(Icons.delete_outline, color: PiColors.error), title: const Text('Delete', style: TextStyle(color: PiColors.error)), onTap: () => Navigator.pop(ctx, 'delete')),
              ],
            ),
          ),
        );
        if (!context.mounted) return;
        switch (action) {
          case 'rename':
            onRename();
          case 'stop':
            onStop();
          case 'delete':
            onDelete();
          default:
            break;
        }
      },
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _BgSessionRow extends StatelessWidget {
  final String cwd;
  final String status;
  final int pending;
  final VoidCallback onOpen;
  final VoidCallback onAbort;

  const _BgSessionRow({
    required this.cwd,
    required this.status,
    required this.pending,
    required this.onOpen,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final running = status == 'running';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          StatusDot(type: running ? StatusDotType.live : StatusDotType.idle, size: 6),
          const SizedBox(width: 8),
          Expanded(child: Text(cwd, style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono'), maxLines: 1, overflow: TextOverflow.ellipsis)),
          StatusChip(label: '$pending pending', variant: ChipVariant.muted),
          const SizedBox(width: 8),
          TextButton(onPressed: onOpen, child: const Text('Open')),
          TextButton(onPressed: onAbort, child: const Text('Abort')),
        ],
      ),
    );
  }
}
