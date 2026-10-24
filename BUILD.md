# A-Coder Mobile — Build Status

_Last updated: 2026-10-25_

## Product

A Flutter client (iOS + Android) that pairs once with a desktop running
`a-coder-cli serve`, then watches and drives the coding agent from anywhere on
the LAN: live streaming transcript, approvals, steering, queued follow-ups,
sessions, models, and settings.

```
Flutter app ──WS(/rpc, Bearer)── a-coder-cli serve ──stdio NDJSON── engine (--mode rpc)
```

- Protocol contract: [`plan/03-protocol-spec.md`](plan/03-protocol-spec.md)
- Bridge spec: [`plan/04-bridge-spec.md`](plan/04-bridge-spec.md)
- App architecture: [`plan/05-app-architecture.md`](plan/05-app-architecture.md)
- Screens: [`plan/06-screens-spec.md`](plan/06-screens-spec.md)
- Test strategy + honest gap list: [`QA.md`](QA.md)

## Where things live

| Path | What |
|---|---|
| `app/` | Flutter client (all code + tests) |
| `plan/` | Build plan and protocol/screens/design specs |
| `QA.md` | Test commands, device matrix, known coverage gaps |
| `.github/workflows/mobile.yml` | CI: analyze + tests + coverage |
| `bridge/` | **Retired.** Canonical bridge lives in the CLI repo (see `bridge/README.md`) |

The bridge is now `a-coder-cli serve`:
`../a-coder-cli/packages/coding-agent/src/serve/` with tests in
`../a-coder-cli/packages/coding-agent/test/serve/`.

## Shipped

**M0/M1 — Bridge (in the CLI repo)**

- Authenticated WS at `/rpc`, `/health`, `/info`; timing-safe token check;
  10/15-min per-IP rate limit; mDNS announce (`_a-coder._tcp`); QR + manual code.
- Engine pump spawns `--mode rpc`, NDJSON fan-out, single-writer queue,
  crash restart (max 2), idle exit, graceful SIGTERM/SIGINT shutdown.
- Hardened for mobile: bounded per-client send queues with `slow_client`
  eviction, engine stdout never blocks on a slow socket, keepalive ping,
  shutdown drain (~2 s), 16 MiB line cap.
- 42 vitest tests pass (+4 env-gated real-engine conformance tests).

**M2/M3/M4 — Client core**

- Protocol: typed messages/commands/events/responses; LF-only wire codec with
  U+2028 safety, bounded accumulation, multi-MB lines.
- Connection: state machine, exponential backoff (1→2→4→8→15 s ±20 %),
  single in-flight connect, resume/network-change coalescing, ordered resync
  (`get_state` → `get_messages` → `get_sessions_status`), stale-response
  discard, terminal 401 handling, no completer/timer leaks.
- Hosts: secure token storage (Keychain/Keystore), atomic metadata writes,
  corrupt-state healing, active-host fallback.
- Chat: streaming transcript (16 fps coalescing), thinking blocks, markdown +
  syntax highlight with bounded LRU cache, inline tool cards (bash/read/write/
  edit diffs) with status + elapsed + bounded output, approvals with countdown
  and always-allow rules, question/select/input/editor/notify cards, queue with
  restore/remove, scroll anchoring with jump-to-latest, skeleton loading.
- Sessions: typed rows, search (debounced), rename with undo, delete/stop
  confirmation, child-session badge, background sheet with abort.
- Pairing: QR scan + manual entry + LAN discovery states, validation, recovery.
- Settings: machines (test/remove/active), appearance (theme, chat text size),
  about, forget-device guard.
- Platform: iOS ATS/Bonjour/camera/photo-library keys; Android cleartext +
  network state; backups disabled for pairing secrets; release icons/splash.
- Accessibility pass in progress: semantics on primary controls, reduced-motion
  handling, 200 % text-scale checks.

## Verification (current)

```bash
cd app
flutter pub get
flutter analyze     # No issues found
flutter test        # 130 passing
```

Release APKs are built at `app/build/app/outputs/flutter-apk/`
(`app-arm64-v8a-release.apk` ≈ 31 MB).

## CI

`.github/workflows/mobile.yml` runs `flutter analyze` + `flutter test
--coverage` on Ubuntu and uploads `lcov.info`.

## Remaining

1. **Device/E2E validation** — no emulator or simulator is available in this
   environment; `app/integration_test/happy_path_test.dart` compiles and runs
   against the in-process fake bridge once a device is attached. The manual
   matrix in `QA.md` is unexecuted.
2. **Chat polish** — long-press copy, tool-detail sheet, error retry card,
   remaining semantics, build-count perf test (tracked as the final chat pass).
3. **Functional parity** — `rewind` (file history), transcript pagination
   (`get_transcript_page`) for very long sessions, attachment hydration
   (`get_attachment`).
4. **M6 extensions (flagged off)** — cron surface, Your Office, `wss://` +
   pinned cert, push relay spike.
