// lib/features/sessions/screens/home_screen.dart
library;
/// Session list & status (doc 06 §2).
/// Header: machine name + connection pill, chips row, search field, session list, FAB.
/// Wired in M3: sessions from list_sessions, background sessions from
/// get_sessions_status, connection pill from SessionController.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connection/connection_state.dart' as cs;
import '../../../design/theme.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true; // keep alive when tab is hidden

  @override
  void initState() {
    super.initState();
    // Keep the connection provider alive while Home is open and fetch once.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hostAsync = ref.watch(activeHostProvider);
    final sessions = ref.watch(sessionsListProvider);
    final background = ref.watch(backgroundSessionsProvider);
    final chat = ref.watch(chatStateProvider);
    final conn = ref.watch(sessionControllerProvider(widget.activeHostId));
    final hostName = hostAsync.value?.name ?? 'A-Coder';

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
          // Connection pill
          IconButton(
            icon: StatusDot(
              type: switch (conn.connection.state) {
                cs.ConnectionState.ready => StatusDotType.live,
                cs.ConnectionState.disconnected => StatusDotType.idle,
                _ => StatusDotType.idle,
              },
              size: 8,
            ),
            onPressed: () => _showConnectionSheet(context, conn),
            tooltip: 'Connection status',
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Chips row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (chat.isStreaming)
                  const StatusChip(label: '● streaming', variant: ChipVariant.accent),
                if (chat.isStreaming) const SizedBox(width: 8),
                if (background.isNotEmpty)
                  StatusChip(
                    label: '${background.length} background',
                    variant: ChipVariant.muted,
                    onTap: () => _showBackgroundSheet(context, background),
                  ),
                if (background.isNotEmpty) const SizedBox(width: 8),
                if (chat.queue.isNotEmpty)
                  StatusChip(
                    label: 'queue ${chat.queue.steering.length + chat.queue.followUp.length}',
                    variant: ChipVariant.tool,
                  ),
              ],
            ),
          ),
          // ─── Search field ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              onChanged: (q) => setState(() => _searchQuery = q),
              decoration: InputDecoration(
                hintText: 'Search sessions by name or path...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          // ─── Session list (pull-to-refresh = list_sessions) ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(sessionControllerProvider(widget.activeHostId).notifier).refreshSessions();
                } catch (_) {}
              },
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final session = filtered[index];
                  return _SessionRow(
                    name: (session.name?.isNotEmpty ?? false) ? session.name! : (session.firstMessage ?? session.id),
                    time: DateTime.tryParse(session.modified) ?? DateTime.now(),
                    messageCount: session.messageCount,
                    path: session.cwd,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pushNamed(
                        '/chat',
                        arguments: {'hostId': widget.activeHostId, 'sessionPath': session.path},
                      );
                    },
                    onLongPress: () => _renameSession(session),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // ─── FAB: new session ─────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = ref.read(sessionControllerProvider(widget.activeHostId).notifier);
          try {
            await controller.newSession();
          } catch (_) {
            // Not connected yet — still open the chat (it will show the banner).
          }
          if (mounted) {
            Navigator.of(context).pushNamed(
              '/chat',
              arguments: {'hostId': widget.activeHostId},
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _renameSession(dynamic session) async {
    final controller = ref.read(sessionControllerProvider(widget.activeHostId).notifier);
    final nameController = TextEditingController(text: (session.name as String?) ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename session'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Session name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rename')),
        ],
      ),
    );
    if (newName == true && mounted) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        try {
          await controller.renameSession(session.path as String, name);
          await controller.refreshSessions();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rename failed — not connected')),
            );
          }
        }
      }
    }
  }

  void _showConnectionSheet(BuildContext context, SessionControllerState conn) {
    final host = ref.read(activeHostProvider).value;
    final url = host?.wsUrl ?? '—';
    final connected = conn.connection.state == cs.ConnectionState.ready;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [StatusDot(type: StatusDotType.live)]),
            const SizedBox(height: 8),
            Text(
              connected ? 'Connected' : (conn.connection.state.name),
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
    );
  }

  void _showBackgroundSheet(BuildContext context, List<dynamic> sessions) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Background Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Text('No background sessions', style: TextStyle(fontSize: 13, color: PiColors.textMuted)),
            // RuntimeSessionStatus rows.
            for (final s in sessions)
              _BgSessionRow(
                cwd: s.cwd as String,
                status: s.status as String,
                pending: s.pendingMessageCount as int,
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final String name;
  final DateTime time;
  final int messageCount;
  final String path;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SessionRow({required this.name, required this.time, required this.messageCount, required this.path, required this.onTap, this.onLongPress});

  @override Widget build(BuildContext context) {
    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(path, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(_relativeTime(time), style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
              const SizedBox(width: 12),
              Text('$messageCount messages', style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: PiColors.textFaint),
      onTap: onTap,
      onLongPress: onLongPress,
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
  final String status; // running | needsInput
  final int pending;

  const _BgSessionRow({required this.cwd, required this.status, required this.pending});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          StatusDot(type: status == 'running' ? StatusDotType.live : StatusDotType.idle, size: 6),
          const SizedBox(width: 8),
          Expanded(child: Text(cwd, style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono'))),
          StatusChip(label: '$pending pending', variant: ChipVariant.muted),
        ],
      ),
    );
  }
}
