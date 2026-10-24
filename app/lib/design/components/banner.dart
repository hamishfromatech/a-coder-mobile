// lib/design/components/banner.dart
library;
/// Full-width strip above composer for connection/compaction/retry states.
/// Shows state icon + message + optional action button.
import 'package:flutter/material.dart';
import '../theme.dart';
enum BannerType {
  reconnecting, // "Reconnecting… attempt N"
  disconnected, // "Disconnected — tap to retry"
  engineRestarting, // "Engine restarting…"
  compaction, // "Compacting context…"
  retrying, // "Retrying (attempt N/M)…"
  info, // Generic info
}
class ConnectionBanner extends StatelessWidget {
  final BannerType type;
  final String message;
  final String? attemptText; // e.g. "attempt 3" or "attempt 3/5"
  final VoidCallback? onRetry;
  final Duration? countdown; // optional remaining time
  const ConnectionBanner({
    super.key,
    required this.type,
    required this.message,
    this.attemptText,
    this.onRetry,
    this.countdown,
  });
  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final (icon, color) = switch (type) {
      BannerType.reconnecting => (const Icon(Icons.sync_problem_rounded, size: 16), PiColors.warning),
      BannerType.disconnected => (const Icon(Icons.wifi_off_rounded, size: 16), PiColors.error),
      BannerType.engineRestarting => (const Icon(Icons.restart_alt_rounded, size: 16), PiColors.accent),
      BannerType.compaction => (const Icon(Icons.compress_rounded, size: 16), PiColors.accent),
      BannerType.retrying => (const Icon(Icons.refresh_rounded, size: 16), PiColors.warning),
      BannerType.info => (const Icon(Icons.info_outline_rounded, size: 16), c.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(icon.icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                if (attemptText != null || countdown != null)
                  Row(
                    children: [
                      if (attemptText != null) ...[
                        Text(attemptText!, style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: c.textMuted)),
                        if (countdown != null) const SizedBox(width: 8),
                      ],
                      if (countdown != null)
                        Text(
                          _formatDuration(countdown!),
                          style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: c.textMuted),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              onPressed: onRetry,
              color: color,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}