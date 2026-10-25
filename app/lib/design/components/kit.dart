// Desktop-parity card / badge / switch / segmented control.
// Sources: desktop-app/src/components/ui/{Card,Badge,Switch,SegmentedControl}.tsx
library;

import 'package:flutter/material.dart';

import '../primitives.dart';
import '../theme.dart';

// ─── Card ──────────────────────────────────────────────────────────────────

class PiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const PiCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = PiRadius.lg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: PiColors.surfaceRaised,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: PiColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class PiCardHeader extends StatelessWidget {
  final Widget child;
  const PiCardHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: PiColors.border)),
        ),
        child: child,
      );
}

class PiCardBody extends StatelessWidget {
  final Widget child;
  const PiCardBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: child);
}

// ── Badge ─────────────────────────────────────────────────────────────────

enum PiBadgeVariant {
  standard,
  accent,
  success,
  error,
  warning,
  muted,
  outline
}

enum PiBadgeSize { sm, md, lg }

class PiBadge extends StatelessWidget {
  final String label;
  final PiBadgeVariant variant;
  final PiBadgeSize size;
  final IconData? icon;

  const PiBadge({
    super.key,
    required this.label,
    this.variant = PiBadgeVariant.standard,
    this.size = PiBadgeSize.md,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      PiBadgeVariant.standard => (
          PiColors.surfaceOverlay,
          PiColors.textSecondary
        ),
      PiBadgeVariant.accent => (PiColors.accentSoft, PiColors.accent),
      PiBadgeVariant.success => (
          PiColors.success.withValues(alpha: 0.10),
          PiColors.success
        ),
      PiBadgeVariant.error => (
          PiColors.error.withValues(alpha: 0.10),
          PiColors.error
        ),
      PiBadgeVariant.warning => (
          PiColors.warning.withValues(alpha: 0.10),
          PiColors.warning
        ),
      PiBadgeVariant.muted => (PiColors.surfaceRaised, PiColors.textMuted),
      PiBadgeVariant.outline => (Colors.transparent, PiColors.textMuted),
    };
    final (padH, padV, fontSize) = switch (size) {
      PiBadgeSize.sm => (4.0, 2.0, 9.0),
      PiBadgeSize.md => (6.0, 2.0, 10.0),
      PiBadgeSize.lg => (8.0, 4.0, 11.0),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PiRadius.sm),
        border: Border.all(
          color: variant == PiBadgeVariant.outline
              ? PiColors.border
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Switch ────────────────────────────────────────────────────────────────

enum PiSwitchSize { sm, md }

/// Desktop switch: 28x18 / 32x20 track, 14/16 knob, accent when on.
class PiSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final PiSwitchSize size;

  const PiSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.size = PiSwitchSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final isSm = size == PiSwitchSize.sm;
    final width = isSm ? 28.0 : 32.0;
    final height = isSm ? 18.0 : 20.0;
    final knob = isSm ? 14.0 : 16.0;
    final inset = (height - knob) / 2;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: EdgeInsets.all(inset),
          decoration: BoxDecoration(
            color: value ? PiColors.accent : PiColors.surfaceRaised,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: value ? Colors.transparent : PiColors.border,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Segmented control ─────────────────────────────────────────────────────

class PiSegment<T> {
  final T value;
  final String label;
  const PiSegment(this.value, this.label);
}

/// Compact mutually-exclusive choice (desktop `SegmentedControl`).
class PiSegmentedControl<T> extends StatelessWidget {
  final List<PiSegment<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;

  const PiSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: PiColors.surfaceRaised,
        borderRadius: BorderRadius.circular(PiRadius.md),
        border: Border.all(color: PiColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: PiColors.textFaint,
                ),
              ),
            ),
          for (final option in options)
            GestureDetector(
              onTap: () => onChanged(option.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: option.value == value
                      ? PiColors.accentSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(PiRadius.sm),
                ),
                child: Text(
                  option.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: PiFonts.mono,
                    letterSpacing: 0.5,
                    color: option.value == value
                        ? PiColors.accent
                        : PiColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
