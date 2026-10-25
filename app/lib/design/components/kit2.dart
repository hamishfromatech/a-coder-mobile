// Desktop-parity search field, modal, error state, tip, fade scroll, loader.
// Sources: desktop-app/src/components/ui/{SearchField,Modal,ErrorState,Tip,
// FadeScroll,Loader}.tsx
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../primitives.dart';
import '../theme.dart';

// ─── SearchField ───────────────────────────────────────────────────────────

/// Borderless search: hairline underline appears on focus, clear affordance
/// shows only with text (desktop `SearchField`).
class PiSearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final String placeholder;
  final String semanticLabel;
  final bool visible;
  final bool autoFocus;
  final VoidCallback? onSubmit;

  const PiSearchField({
    super.key,
    required this.value,
    required this.onChange,
    required this.semanticLabel,
    this.placeholder = 'Search…',
    this.visible = true,
    this.autoFocus = false,
    this.onSubmit,
  });

  @override
  State<PiSearchField> createState() => _PiSearchFieldState();
}

class _PiSearchFieldState extends State<PiSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    if (widget.autoFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void didUpdateWidget(covariant PiSearchField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _focused ? PiColors.borderStrong : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: PiColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: widget.onChange,
              onSubmitted: (_) => widget.onSubmit?.call(),
              autofocus: widget.autoFocus,
              style: TextStyle(fontSize: 11, color: PiColors.text),
              cursorColor: PiColors.accent,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.placeholder,
                hintStyle: TextStyle(fontSize: 11, color: PiColors.textFaint),
              ),
            ),
          ),
          if (widget.value.isNotEmpty)
            GestureDetector(
              onTap: () => widget.onChange(''),
              child: Semantics(
                label: 'Clear search',
                child: Icon(Icons.close, size: 12, color: PiColors.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Modal ─────────────────────────────────────────────────────────────────

/// Desktop overlay panel: dimmed backdrop, surface-overlay card, radius xl,
/// layered shadow, scale + rise entrance.
class PiModalPanel extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool centered;

  const PiModalPanel({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
        ),
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: centered ? height * 0.86 : height * 0.92,
        ),
        decoration: BoxDecoration(
          color: PiColors.surfaceOverlay,
          borderRadius: BorderRadius.circular(PiRadius.xl),
          border: Border.all(color: PiColors.border),
          boxShadow: piOverlayShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Show a centered modal in the desktop's visual language.
Future<T?> showPiModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 560,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.60),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PiModalPanel(maxWidth: maxWidth, child: builder(dialogContext)),
      ),
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Mobile-adapted equivalent of the desktop panel: a bottom sheet with the
/// same surface, radius and shadow.
Future<T?> showPiSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (sheetContext) => Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: PiColors.surfaceOverlay,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PiRadius.xxl),
        ),
        border: Border(top: BorderSide(color: PiColors.border)),
        boxShadow: piOverlayShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: builder(sheetContext),
    ),
  );
}

// ─── Error state ───────────────────────────────────────────────────────────

/// Canonical error glyph (desktop `ErrorIcon`).
class PiErrorIcon extends StatelessWidget {
  final double size;
  const PiErrorIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.error_outline_rounded, size: size, color: PiColors.error);
}

class PiErrorState extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> actions;

  const PiErrorState({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PiErrorIcon(size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PiColors.text,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: PiColors.textMuted,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tip ───────────────────────────────────────────────────────────────────

/// Themed tooltip: 200 ms open delay (desktop contract), surface overlay.
class PiTip extends StatelessWidget {
  final String message;
  final Widget child;

  const PiTip({super.key, required this.message, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 200),
      textStyle: TextStyle(fontSize: 11, color: PiColors.text),
      decoration: BoxDecoration(
        color: PiColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(PiRadius.md),
        border: Border.all(color: PiColors.border),
        boxShadow: piOverlayShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: child,
    );
  }
}

// ─── FadeScroll ────────────────────────────────────────────────────────────

/// Scroll content that fades under the top/bottom edge only while there is
/// more to scroll that way (desktop `FadeScroll`).
class PiFadeScroll extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final double fade;

  const PiFadeScroll({
    super.key,
    required this.child,
    this.controller,
    this.fade = 14,
  });

  @override
  State<PiFadeScroll> createState() => _PiFadeScrollState();
}

class _PiFadeScrollState extends State<PiFadeScroll> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();
  bool _atTop = true;
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final top = pos.pixels > 2;
    final bottom = pos.pixels + pos.viewportDimension < pos.maxScrollExtent - 2;
    if (top != _atTop || bottom != _atBottom) {
      setState(() {
        _atTop = !top;
        _atBottom = !bottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_atTop)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.fade,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [PiColors.bg, PiColors.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        if (!_atBottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: widget.fade,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [PiColors.bg, PiColors.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Loader ────────────────────────────────────────────────────────────────

/// Accent spinner with optional caption (desktop `Loader` collapsed to the
/// single-color variant; the parametric curve loaders are a later pass).
class PiLoader extends StatelessWidget {
  final String? label;
  final double size;

  const PiLoader({super.key, this.label, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PiColors.accent,
            backgroundColor: PiColors.accentSoft,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: PiColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Curve loader (desktop `Loader.tsx` port) ───────────────────────────────

enum PiLoaderCurve { lemniscateBloom, roseCurve, roseOrbit }

/// The desktop's parametric trail loaders: 64 particles swept along a curve
/// with a pulse and a slow rotation.
class PiCurveLoader extends StatefulWidget {
  final PiLoaderCurve type;
  final double size;
  final String? label;

  const PiCurveLoader({
    super.key,
    this.type = PiLoaderCurve.lemniscateBloom,
    this.size = 56,
    this.label,
  });

  @override
  State<PiCurveLoader> createState() => _PiCurveLoaderState();
}

class _PiCurveLoaderState extends State<PiCurveLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final double _phaseOffset = 0.37;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _spec.durationMs),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _CurveSpec get _spec => switch (widget.type) {
        PiLoaderCurve.lemniscateBloom => const _CurveSpec(
            durationMs: 5600,
            pulseDurationMs: 5000,
            rotationDurationMs: 34000,
            trailSpan: 0.4,
            strokeWidth: 4.8,
          ),
        PiLoaderCurve.roseCurve => const _CurveSpec(
            durationMs: 5400,
            pulseDurationMs: 4600,
            rotationDurationMs: 28000,
            trailSpan: 0.32,
            strokeWidth: 4.5,
          ),
        PiLoaderCurve.roseOrbit => const _CurveSpec(
            durationMs: 5200,
            pulseDurationMs: 4600,
            rotationDurationMs: 28000,
            trailSpan: 0.42,
            strokeWidth: 5.2,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: reduceMotion
              ? CustomPaint(
                  painter: _CurvePainter(
                    type: widget.type,
                    spec: _spec,
                    progress: 0.3,
                    phaseOffset: 0.0,
                    color: PiColors.accent,
                  ),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _CurvePainter(
                      type: widget.type,
                      spec: _spec,
                      progress: _controller.value,
                      phaseOffset: _phaseOffset,
                      color: PiColors.accent,
                    ),
                  ),
                ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: PiColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _CurveSpec {
  final int durationMs;
  final int pulseDurationMs;
  final int rotationDurationMs;
  final double trailSpan;
  final double strokeWidth;
  const _CurveSpec({
    required this.durationMs,
    required this.pulseDurationMs,
    required this.rotationDurationMs,
    required this.trailSpan,
    required this.strokeWidth,
  });
}

class _CurvePainter extends CustomPainter {
  final PiLoaderCurve type;
  final _CurveSpec spec;
  final double progress;
  final double phaseOffset;
  final Color color;

  _CurvePainter({
    required this.type,
    required this.spec,
    required this.progress,
    required this.phaseOffset,
    required this.color,
  });

  static const _twoPi = 6.283185307179586;

  double _normalize(double p) => ((p % 1) + 1) % 1;

  double _detailScale(double time) {
    final pulse =
        ((time + phaseOffset * spec.pulseDurationMs) % spec.pulseDurationMs) /
            spec.pulseDurationMs;
    return 0.52 + ((math.sin(pulse * _twoPi + 0.55) + 1) / 2) * 0.48;
  }

  _Point _point(double p, double detail) {
    final t = p * _twoPi;
    switch (type) {
      case PiLoaderCurve.lemniscateBloom:
        final scale = 20 + detail * 7;
        final denom = 1 + math.pow(math.sin(t), 2);
        return _Point(
          50 + (scale * math.cos(t)) / denom,
          50 + (scale * math.sin(t) * math.cos(t)) / denom,
        );
      case PiLoaderCurve.roseCurve:
        final a = 9.2 + detail * 0.6;
        final r = a * (0.72 + detail * 0.28) * math.cos(5 * t);
        return _Point(
          50 + math.cos(t) * r * 3.25,
          50 + math.sin(t) * r * 3.25,
        );
      case PiLoaderCurve.roseOrbit:
        final r = 7 - 2.7 * detail * math.cos(7 * t);
        return _Point(
          50 + math.cos(t) * r * 3.9,
          50 + math.sin(t) * r * 3.9,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * spec.durationMs;
    final detail = _detailScale(time);
    final rotation = -((time + phaseOffset * spec.rotationDurationMs) %
            spec.rotationDurationMs) /
        spec.rotationDurationMs *
        _twoPi;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.shortestSide / 100;
    canvas.scale(scale, scale);
    canvas.rotate(rotation);
    canvas.translate(-50, -50);

    // Faint full path.
    final path = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final point = _point(i / steps, detail);
      if (i == 0) {
        path.moveTo(point.x, point.y);
      } else {
        path.lineTo(point.x, point.y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.strokeWidth * 0.35
        ..strokeCap = StrokeCap.round,
    );

    // Particle trail.
    const count = 64;
    for (var i = 0; i < count; i++) {
      final tail = i / (count - 1);
      final point =
          _point(_normalize(progress - tail * spec.trailSpan), detail);
      final fade = math.pow(1 - tail, 0.56).toDouble();
      final radius = (0.9 + fade * 2.7);
      canvas.drawCircle(
        Offset(point.x, point.y),
        radius,
        Paint()..color = color.withValues(alpha: 0.04 + fade * 0.96),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.progress != progress || old.type != type || old.color != color;
}

class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}

/// Thin indeterminate bar for panel headers (mobile-adapted).
class PiLoadingBar extends StatelessWidget {
  const PiLoadingBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          minHeight: 2,
          color: PiColors.accent,
          backgroundColor: PiColors.accentSoft,
        ),
      );
}

/// Debounce helper shared by search-like fields.
class PiDebouncer {
  final Duration delay;
  Timer? _timer;
  PiDebouncer([this.delay = const Duration(milliseconds: 200)]);

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
