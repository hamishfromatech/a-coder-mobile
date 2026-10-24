// ConnectingOverlay — ported from desktop ConnectingOverlay.tsx. Full-screen
// "CONNECTING" scramble-decode text shown while the bridge connects on cold
// boot, then an exit choreography (text fades down + out, hold, overlay fades)
// once connected. After a healthy boot it never resurrects — soft reconnects
// keep the shell visible (the home screen's connection banner owns those).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connection/connection_state.dart' as conn;
import '../../design/components/decode_text.dart';
import '../../design/theme.dart';
import '../pairing/providers/connection_providers.dart';

// Exit choreography (ms): text fades down + out, hold, then the overlay fades.
const _textOutMs = Duration(milliseconds: 360);
const _postTextHoldMs = Duration(milliseconds: 300);
const _overlayOutMs = Duration(milliseconds: 520);

enum _Phase { live, textOut, overlayOut, gone }

class ConnectingOverlay extends ConsumerStatefulWidget {
  const ConnectingOverlay({super.key, required this.hostId});

  final String hostId;

  @override
  ConsumerState<ConnectingOverlay> createState() => _ConnectingOverlayState();
}

class _ConnectingOverlayState extends ConsumerState<ConnectingOverlay> {
  _Phase _phase = _Phase.live;
  // Once cold boot has completed once, never resurrect the overlay.
  bool _coldBootDone = false;
  // Latch so the brief frame where the state flips to ready before the exit
  // phase kicks in doesn't unmount us and cause a flash.
  bool _shown = false;
  Timer? _phaseTimer;
  Timer? _tick;
  int _seconds = 0;
  bool _connectingNow = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_connectingNow || _phase != _Phase.live) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _setPhase(_Phase phase) {
    _phaseTimer?.cancel();
    setState(() => _phase = phase);
    switch (phase) {
      case _Phase.textOut:
        _phaseTimer = Timer(_textOutMs + _postTextHoldMs, () {
          if (mounted) _setPhase(_Phase.overlayOut);
        });
      case _Phase.overlayOut:
        _phaseTimer = Timer(_overlayOutMs, () {
          if (mounted) setState(() => _phase = _Phase.gone);
        });
      case _Phase.live || _Phase.gone:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionStateProvider(widget.hostId));
    final info = state.connection;
    final ready = state.isReady;

    if (ready) {
      _coldBootDone = true;
    }

    // The full-screen overlay is for initial boot only. After a healthy boot,
    // a dropped socket / reconnect must NOT cover the chat — users should
    // still be able to type drafts and recover instead of staring at a modal.
    // An auth/server error surfaces through the home screen's banner instead.
    final hasFatalError =
        info.state == conn.ConnectionState.disconnected && (info.errorMessage?.isNotEmpty ?? false);
    final connecting =
        !_coldBootDone && !ready && !hasFatalError && info.state != conn.ConnectionState.shuttingDown;

    _connectingNow = connecting;
    if (!connecting) _seconds = 0;

    if (connecting) {
      _shown = true;
    }

    // Kick off the exit once connected. Under reduced motion, skip the
    // multi-phase choreography and jump straight to gone.
    if (_phase == _Phase.live && ready && _shown) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setPhase(reduced ? _Phase.gone : _Phase.textOut);
      });
    }

    // Boot failed before ever connecting — step aside so the home screen's
    // error/re-pair prompt owns the screen.
    if (hasFatalError && !connecting && _phase == _Phase.live) {
      return const SizedBox.shrink();
    }

    // Real connect: once the fade finishes, get out of the way for good.
    if (_phase == _Phase.gone) {
      return const SizedBox.shrink();
    }

    // Never showed (warm start, already connected) — stay out.
    if (!connecting && !_shown) {
      return const SizedBox.shrink();
    }

    final leaving = _phase != _Phase.live;
    final overlayHidden = _phase == _Phase.overlayOut;
    final palette = PiColors.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      ignoring: leaving,
      child: AnimatedOpacity(
        opacity: overlayHidden ? 0 : 1,
        duration: reduced ? Duration.zero : _overlayOutMs,
        curve: Curves.easeOut,
        child: ColoredBox(
          color: palette.bg,
          child: Center(
            child: AnimatedSlide(
              offset: leaving ? const Offset(0, 0.12) : Offset.zero,
              duration: reduced ? Duration.zero : _textOutMs,
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: leaving ? 0 : 1,
                duration: reduced ? Duration.zero : _textOutMs,
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecodeText(
                      active: _phase == _Phase.live && connecting && !reduced,
                      cursor: true,
                      text: 'CONNECTING',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 12 * 0.4,
                        color: PiColors.accent,
                      ),
                    ),
                    // Never leave the user staring at a silent screen: show
                    // what the stack is doing, surface errors, and offer a
                    // manual retry once the handshake looks stuck.
                    if (!leaving) ...[
                      if (info.state == conn.ConnectionState.reconnecting)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            info.nextRetryIn > Duration.zero
                                ? 'retrying in ${info.nextRetryIn.inSeconds}s'
                                : 'retrying…',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: palette.textMuted,
                            ),
                          ),
                        )
                      else if (info.isResyncing)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'loading your session…',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: palette.textMuted,
                            ),
                          ),
                        )
                      else if (_seconds >= 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'waiting for the desktop engine…',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      if (info.errorMessage != null &&
                          info.errorMessage!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              info.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: PiColors.error),
                            ),
                          ),
                        ),
                      if (_seconds >= 8)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextButton(
                            onPressed: () {
                              ref
                                  .read(sessionControllerProvider(widget.hostId)
                                      .notifier)
                                  .forceReconnectNow();
                              setState(() => _seconds = 0);
                            },
                            child: Text('Retry',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textSecondary)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}