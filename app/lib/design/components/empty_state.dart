// lib/design/components/empty_state.dart
library;
/// Standardized empty/error/loading states (doc 09 §4).
/// EmptyState, ErrorState, LoadingList — used across all screens.
import 'package:flutter/material.dart';
import '../theme.dart';
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? action;
  final String? actionLabel;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
    this.actionLabel,
  });
  @override Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PiColors.textFaint),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: PiColors.textSecondary)),
            const SizedBox(height: 4),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: PiColors.textMuted)),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: action,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: PiColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: PiColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
/// Shimmer loading rows matching final layout heights.
class LoadingList extends StatelessWidget {
  final int itemCount;
  const LoadingList({super.key, this.itemCount = 10});
  @override Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => _ShimmerRow(index == 0),
    );
  }
}
class _ShimmerRow extends StatefulWidget {
  final bool isLast;
  const _ShimmerRow(this.isLast);
  @override State<_ShimmerRow> createState() => _ShimmerRowState();
}
class _ShimmerRowState extends State<_ShimmerRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
    _controller.repeat();
  }
  @override void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    final c = PiColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Opacity(
          opacity: _animation.value,
          child: Container(
            height: widget.isLast ? 120 : 64,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}