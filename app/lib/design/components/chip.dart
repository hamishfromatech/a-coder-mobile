// lib/design/components/chip.dart
library;

/// Pill chip — mono 10sp; accent=live/model, muted=idle, success, error variants.
/// Matches desktop's `text-4xs uppercase tracking-[0.08em]`.
import 'package:flutter/material.dart';
import '../theme.dart';

enum ChipVariant { accent, muted, success, error, tool }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipVariant variant;
  final VoidCallback? onTap;
  const StatusChip(
      {super.key,
      required this.label,
      this.variant = ChipVariant.muted,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final (bgColor, textColor) = switch (variant) {
      ChipVariant.accent => (c.accentSoft, PiColors.accent),
      ChipVariant.muted => (c.textFaint.withValues(alpha: 0.15), c.textMuted),
      ChipVariant.success => (
          PiColors.success.withValues(alpha: c.isDark ? 0.14 : 0.10),
          PiColors.success
        ),
      ChipVariant.error => (
          PiColors.error.withValues(alpha: c.isDark ? 0.14 : 0.10),
          PiColors.error
        ),
      ChipVariant.tool => (
          PiColors.toolIdentity.withValues(alpha: c.isDark ? 0.14 : 0.10),
          PiColors.toolIdentity
        ),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: PiFonts.mono,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
