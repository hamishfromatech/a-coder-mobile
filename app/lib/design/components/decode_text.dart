// DecodeText — scramble-decode text, ported from desktop DecodeText.tsx.
// Even-weight mono charset so cycling glyphs never jump width. Decode resolves
// half a character per 45ms tick; when fully resolved it holds 16 ticks, then
// (in loop mode) replays. The first `prefix` characters NEVER scramble —
// split at render level so no timer logic can garble them. Optional blinking
// cursor square after the text.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

const decodeScrambleChars = r'/\|-_=+<>~:*';
const _tickMs = Duration(milliseconds: 45);
const _holdTicks = 16;
final _random = Random();

class DecodeText extends StatefulWidget {
  const DecodeText({
    super.key,
    required this.text,
    this.prefix = 0,
    this.active = true,
    this.loop = true,
    this.cursor = false,
    this.style,
  });

  final String text;

  /// Leading character count that stays legible at all times.
  final int prefix;

  /// Run the decode. When false, renders the plain resolved text (freezes the
  /// word during the exit choreography).
  final bool active;

  /// Replay after the hold, or resolve once and stop.
  final bool loop;

  /// Blinking cursor square after the text.
  final bool cursor;
  final TextStyle? style;

  @override
  State<DecodeText> createState() => _DecodeTextState();
}

class _DecodeTextState extends State<DecodeText> {
  Timer? _timer;
  double _resolved = 0;
  int _hold = 0;
  late String _tail = _tailText;

  String get _tailText {
    if (widget.text.length <= widget.prefix) return '';
    return widget.text.substring(widget.prefix);
  }

  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    // First scheduling happens in didChangeDependencies — reading MediaQuery
    // (reduced motion) is not allowed in initState.
  }

  @override
  void didUpdateWidget(DecodeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _resolved = 0;
      _hold = 0;
      _tail = _tailText;
    }
    _syncRunning();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncRunning() {
    final shouldRun = widget.active && !_reducedMotion;
    if (shouldRun && _timer == null) {
      _resolved = 0;
      _hold = 0;
      _timer = Timer.periodic(_tickMs, (_) => _tick());
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
      // Frozen render shows the plain resolved text.
      _tail = _tailText;
    }
  }

  void _tick() {
    if (_resolved >= _tailText.length) {
      _hold += 1;
      if (_hold > _holdTicks) {
        if (widget.loop) {
          _resolved = 0;
          _hold = 0;
        } else {
          _timer?.cancel();
          _timer = null;
        }
      }
    } else {
      _resolved += 0.5;
    }
    setState(() => _tail = _scrambled(_tailText, _resolved.floor()));
  }

  static String _scrambled(String tail, int resolvedCount) {
    final out = StringBuffer();
    for (var i = 0; i < tail.length; i++) {
      final ch = tail[i];
      out.write(ch == ' ' || i < resolvedCount
          ? ch
          : decodeScrambleChars[_random.nextInt(decodeScrambleChars.length)]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final staticPrefix = widget.text.length > widget.prefix
        ? widget.text.substring(0, widget.prefix)
        : widget.text;
    final baseStyle = (widget.style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(TextSpan(text: '$staticPrefix$_tail', style: baseStyle)),
        if (widget.cursor) ...[
          const SizedBox(width: 4),
          const _BlinkingCursor()
        ],
      ],
    );
  }
}

/// 1s step-end blink: 500ms visible, 500ms hidden. Honors reduced motion
/// (always visible).
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // First scheduling happens in didChangeDependencies — reading MediaQuery
    // (reduced motion) is not allowed in initState.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= MediaQuery.disableAnimationsOf(context)
        ? null
        : Timer.periodic(const Duration(milliseconds: 500), (_) {
            if (!mounted) return;
            setState(() => _visible = !_visible);
          });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible || MediaQuery.disableAnimationsOf(context);
    return Opacity(
      opacity: visible ? 1 : 0,
      child: Container(
        width: 7,
        height: 7,
        transform: Matrix4.translationValues(0, -1, 0),
        decoration: BoxDecoration(
          color: DefaultTextStyle.of(context).style.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
