// Desktop-parity buttons (desktop-app/src/components/ui/Button.tsx).
//
// Variant + size vocabulary is identical to the desktop so screens port over
// without re-deciding styling. Sizes are the desktop pixel heights; touch
// targets stay >= 44dp through the enclosing row/semantics where needed.
library;

import 'package:flutter/material.dart';

import '../primitives.dart';
import '../theme.dart';

enum PiButtonVariant {
  standard,
  primary,
  secondary,
  outline,
  ghost,
  link,
  text,
  textStrong,
  danger,
  destructive,
  ghostDanger,
}

enum PiButtonSize { xs, sm, md, lg, inline, iconSm, icon, iconLg }

class PiButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final IconData? icon;
  final PiButtonVariant variant;
  final PiButtonSize size;
  final bool loading;
  final bool expanded;
  final VoidCallback? onPressed;

  const PiButton({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.variant = PiButtonVariant.secondary,
    this.size = PiButtonSize.md,
    this.loading = false,
    this.expanded = false,
    this.onPressed,
  });

  double get _height => switch (size) {
        PiButtonSize.xs => 24,
        PiButtonSize.sm => 28,
        PiButtonSize.md => 32,
        PiButtonSize.lg => 36,
        PiButtonSize.inline => 0,
        PiButtonSize.iconSm => 28,
        PiButtonSize.icon => 32,
        PiButtonSize.iconLg => 36,
      };

  double get _radius => size == PiButtonSize.lg || size == PiButtonSize.iconLg
      ? PiRadius.lg
      : PiRadius.md;

  double get _fontSize => switch (size) {
        PiButtonSize.xs || PiButtonSize.sm => 10,
        PiButtonSize.md || PiButtonSize.lg => 11,
        PiButtonSize.inline => 11,
        _ => 11,
      };

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case PiButtonSize.xs:
        return const EdgeInsets.symmetric(horizontal: 8);
      case PiButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10);
      case PiButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 12);
      case PiButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 16);
      case PiButtonSize.inline:
        return EdgeInsets.zero;
      case PiButtonSize.iconSm:
      case PiButtonSize.icon:
      case PiButtonSize.iconLg:
        return EdgeInsets.zero;
    }
  }

  ({Color bg, Color fg, BorderSide? border}) _colors() {
    final border = BorderSide(color: PiColors.border);
    switch (variant) {
      case PiButtonVariant.standard:
      case PiButtonVariant.primary:
        return (bg: PiColors.accent, fg: Colors.white, border: null);
      case PiButtonVariant.secondary:
        return (bg: PiColors.surfaceRaised, fg: PiColors.text, border: border);
      case PiButtonVariant.outline:
        return (
          bg: Colors.transparent,
          fg: PiColors.textSecondary,
          border: border
        );
      case PiButtonVariant.ghost:
        return (
          bg: Colors.transparent,
          fg: PiColors.textSecondary,
          border: null
        );
      case PiButtonVariant.link:
        return (bg: Colors.transparent, fg: PiColors.accent, border: null);
      case PiButtonVariant.text:
      case PiButtonVariant.textStrong:
        return (
          bg: Colors.transparent,
          fg: PiColors.textSecondary,
          border: null
        );
      case PiButtonVariant.danger:
      case PiButtonVariant.destructive:
        return (bg: PiColors.error, fg: Colors.white, border: null);
      case PiButtonVariant.ghostDanger:
        return (
          bg: Colors.transparent,
          fg: PiColors.textSecondary,
          border: null
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    final isLink = variant == PiButtonVariant.link ||
        variant == PiButtonVariant.text ||
        variant == PiButtonVariant.textStrong;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: c.fg),
          )
        else if (icon != null)
          Icon(icon, size: size == PiButtonSize.lg ? 16 : 14, color: c.fg),
        if ((loading || icon != null) && (label != null || child != null))
          const SizedBox(width: 6),
        if (child != null)
          child!
        else if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: size == PiButtonSize.lg ||
                      variant == PiButtonVariant.textStrong
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: c.fg,
              decoration: isLink ? TextDecoration.underline : null,
              decorationColor: c.fg.withValues(alpha: 0.6),
            ),
          ),
      ],
    );

    final button = Material(
      color: c.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: c.border ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onPressed,
        hoverColor: _hoverColor(),
        child: Container(
          height: _height == 0 ? null : _height,
          width: size == PiButtonSize.iconSm
              ? 28
              : size == PiButtonSize.icon
                  ? 32
                  : size == PiButtonSize.iconLg
                      ? 36
                      : null,
          padding: _padding,
          alignment: Alignment.center,
          child: Opacity(opacity: onPressed == null ? 0.5 : 1, child: content),
        ),
      ),
    );
    return Semantics(button: true, enabled: onPressed != null, child: button);
  }

  Color _hoverColor() => switch (variant) {
        PiButtonVariant.primary ||
        PiButtonVariant.standard =>
          PiColors.accentHover.withValues(alpha: 0.18),
        PiButtonVariant.ghostDanger => PiColors.error.withValues(alpha: 0.12),
        _ => PiColors.surfaceOverlay.withValues(alpha: 0.6),
      };
}

/// Square icon-only button (desktop `IconButton`).
class PiIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final PiButtonSize size;
  final PiButtonVariant variant;
  final bool loading;

  const PiIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.size = PiButtonSize.icon,
    this.variant = PiButtonVariant.ghost,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: PiButton(
        icon: icon,
        variant: variant,
        size: size,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}
