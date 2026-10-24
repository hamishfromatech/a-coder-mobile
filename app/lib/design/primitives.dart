// Desktop-parity design primitives (desktop-app/DESIGN.md, index.css).
//
// The mobile theme already mirrors the desktop color tokens 1:1. This file
// carries the *shape and type* half of the contract: the 13/11 px type scale,
// the radius ladder, the glass surface, and the layered overlay shadow.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Desktop type scale (`--conversation-text-font-size` etc.).
class PiType {
  PiType._();

  /// Chat body / composer input / list titles.
  static const double body = 13;

  /// Captions, metadata, tool rows, chips.
  static const double caption = 11;

  /// Section titles inside panels.
  static const double title = 15;

  /// Mono micro labels (chips, status strip, diff gutters).
  static const double micro = 10;

  static TextStyle get bodyStyle =>
      const TextStyle(fontSize: body, height: 1.5);
  static TextStyle get captionStyle => const TextStyle(
      fontSize: caption, height: 1.4, color: PiColors.textMuted);
  static TextStyle get monoMicro => const TextStyle(
        fontSize: micro,
        fontFamily: 'JetBrains Mono',
        letterSpacing: 0.6,
        color: PiColors.textMuted,
      );
}

/// Desktop radius ladder (`--pi-radius-*`).
class PiRadius {
  PiRadius._();
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xxl = 16;
}

/// Layered overlay shadow (`--pi-card-overlay`).
List<BoxShadow> get piOverlayShadow => const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x47000000), blurRadius: 48, offset: Offset(0, 16)),
    ];

/// Desktop `.pi-glass`: translucent raised surface + hairline.
///
/// Intentionally blur-free: the chat chrome behind it is flat, so a
/// `BackdropFilter` would cost compositing for an invisible effect (and the
/// desktop disables it under reduced motion anyway).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double radius;
  final Color? color;
  final bool border;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.constraints,
    this.radius = PiRadius.xl,
    this.color,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = PiColors.of(context);
    return Container(
      padding: padding,
      constraints: constraints,
      decoration: BoxDecoration(
        color: color ?? palette.surfaceRaised.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: PiColors.border) : null,
      ),
      child: child,
    );
  }
}

/// The 28 px circular assistant avatar from the desktop transcript.
class AssistantAvatar extends StatelessWidget {
  final double size;

  const AssistantAvatar({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Assistant',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PiColors.accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.smart_toy_outlined,
            size: size * 0.57, color: PiColors.accent),
      ),
    );
  }
}
