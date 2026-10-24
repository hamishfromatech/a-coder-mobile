// lib/design/components/status_dot.dart
library;
/// 4–8px dot: accent (live, pulse), success (done), error.
/// Used in chips, session list rows, background sessions indicator.
import 'package:flutter/material.dart';
import '../theme.dart';
enum StatusDotType { live, done, error, idle }
class StatusDot extends StatelessWidget {
  final StatusDotType type;
  final double size; // 4–8px
  const StatusDot({super.key, this.type = StatusDotType.idle, this.size = 8});
  @override Widget build(BuildContext context) {
    final color = switch (type) {
      StatusDotType.live => PiColors.accent,
      StatusDotType.done => PiColors.success,
      StatusDotType.error => PiColors.error,
      StatusDotType.idle => PiColors.accent.withValues(alpha: 0.3),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: type == StatusDotType.live
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, _) => Opacity(
                opacity: value,
                child: Container(
                  width: size + 4,
                  height: size + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 1.0 - value * 0.7),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}