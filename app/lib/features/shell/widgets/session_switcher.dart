// Quick session switcher — desktop session tabs collapsed into a sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' show RpcSessionInfo;
import '../../../design/components/kit2.dart';
import '../../../design/components/status_dot.dart';
import '../../../design/theme.dart';
import '../../sessions/providers/sessions_providers.dart';

Future<void> showSessionSwitcher(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
  String? currentPath,
}) {
  return showPiSheet<void>(
    context,
    builder: (_) => _SessionSwitcher(hostId: hostId, currentPath: currentPath),
  );
}

class _SessionSwitcher extends ConsumerWidget {
  final String hostId;
  final String? currentPath;

  const _SessionSwitcher({required this.hostId, this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsListProvider).take(20).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Switch session',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PiColors.text,
                  ),
                ),
              ),
              Text(
                '${sessions.length} recent',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: PiFonts.mono,
                  color: PiColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: PiColors.border),
        Flexible(
          child: sessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No sessions yet',
                    style: TextStyle(fontSize: 12, color: PiColors.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final current =
                        currentPath != null && session.path == currentPath;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        if (current) return;
                        Navigator.of(context).pushReplacementNamed(
                          '/chat',
                          arguments: {
                            'hostId': hostId,
                            'sessionPath': session.path,
                          },
                        );
                      },
                      child: Container(
                        color: current ? PiColors.accentSoft : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            StatusDot(
                              type: current
                                  ? StatusDotType.live
                                  : StatusDotType.idle,
                              size: 7,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(session),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: current
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: PiColors.text,
                                    ),
                                  ),
                                  if (session.cwd.isNotEmpty)
                                    Text(
                                      session.cwd,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: PiFonts.mono,
                                        color: PiColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (current)
                              Icon(Icons.check,
                                  size: 14, color: PiColors.accent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 6),
      ],
    );
  }

  static String _label(RpcSessionInfo s) => s.name?.isNotEmpty == true
      ? s.name!
      : (s.firstMessage?.isNotEmpty == true
          ? s.firstMessage!
          : s.path.split('/').last);
}
