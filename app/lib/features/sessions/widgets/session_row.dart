// lib/features/sessions/widgets/session_row.dart
library;

import 'package:flutter/material.dart';

import '../../../core/protocol/responses.dart' show RpcSessionInfo;
import '../../../design/theme.dart';
import '../../../design/components/chip.dart';

/// One row in the home session list: title, project path, relative age,
/// message count, and a `child` badge for branched sessions.
///
/// Extracted from `HomeScreen` (THE-46) with the rendering unchanged so the
/// row can be golden-tested in isolation. Long-press opens the row actions.
class SessionRow extends StatelessWidget {
  final RpcSessionInfo session;
  final bool connected;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onStop;
  final VoidCallback onTogglePin;
  final VoidCallback? onBranches;

  const SessionRow({
    super.key,
    required this.session,
    required this.connected,
    required this.pinned,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onStop,
    required this.onTogglePin,
    this.onBranches,
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
      leading: pinned
          ? Icon(Icons.push_pin, size: 14, color: PiColors.accent)
          : null,
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(path,
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: PiFonts.mono,
                  color: PiColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(_relativeTime(modified),
                  style: TextStyle(fontSize: 11, color: PiColors.textMuted)),
              const SizedBox(width: 12),
              Text('$msgCount messages',
                  style: TextStyle(fontSize: 11, color: PiColors.textMuted)),
              if (session.parentSessionPath != null) ...[
                const SizedBox(width: 8),
                const StatusChip(label: 'child', variant: ChipVariant.tool),
              ],
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: PiColors.textFaint),
      onTap: onTap,
      onLongPress: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    leading:
                        Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin),
                    title: Text(pinned ? 'Unpin' : 'Pin to top'),
                    onTap: () => Navigator.pop(ctx, 'pin')),
                if (onBranches != null)
                  ListTile(
                      leading: const Icon(Icons.account_tree_outlined),
                      title: const Text('Branches'),
                      onTap: () => Navigator.pop(ctx, 'branches')),
                ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Rename'),
                    onTap: () => Navigator.pop(ctx, 'rename')),
                ListTile(
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: const Text('Stop'),
                    onTap: () => Navigator.pop(ctx, 'stop')),
                ListTile(
                    leading: Icon(Icons.delete_outline, color: PiColors.error),
                    title:
                        Text('Delete', style: TextStyle(color: PiColors.error)),
                    onTap: () => Navigator.pop(ctx, 'delete')),
              ],
            ),
          ),
        );
        if (!context.mounted) return;
        switch (action) {
          case 'pin':
            onTogglePin();
          case 'branches':
            onBranches?.call();
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
