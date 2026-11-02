# A-Coder Mobile — Build Status

_Last updated: 2026-11-03_

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

**M6 — Extensions (shipped behind flags) ✅**

- **Scheduled tasks** (`/cron`, `FeatureFlags.enableCron`): list, enable/disable,
  run now, delete, job detail (prompt, cwd, variables, last error) and run
  history. Fed by `cron_list`/`cron_runs` + `cron_update` pushes.
- **Your Office** (`/office`, `FeatureFlags.enableOffice`): roster with live
  statuses, huddles with previews, errands, pending supervisor prompts, and a
  huddle room (messages, working indicators, send/stop).
- **`wss://` + certificate pinning**: `a-coder-cli serve --tls-cert/--tls-key`
  serves TLS; the QR carries `tls:true` + the SHA-256 `pin`; the app pins
  self-signed LAN certs and shows a TLS/pinned badge per machine. mDNS TXT
  advertises `tls=1`.
- **Push relay**: design spike only (`plan/11-push-relay-spike.md`).

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
- Accessibility: semantics on primary controls, reduced-motion handling,
  200 % text-scale checks, no overflow at 320 dp.
- Transcript paging via `get_transcript_page` (80-entry pages, scroll-up load),
  inline image history with a full-screen viewer, and file-history rewind.

## Desktop visual parity

The mobile UI now follows `desktop-app/DESIGN.md` rather than merely sharing
its color tokens:

- **Type scale**: 13 px conversation body, 11 px captions, 15 px titles, 10 px
  mono micro-labels; dense 13/11 list rows.
- **Chat**: translucent `pi-glass` user bubble (12 px radius, 88 % width,
  hairline), flat assistant rows with the 28 px accent avatar, bordered
  thinking block, hairline tool cards, a 16 px glass composer, and a static
  radial backdrop wash (no per-frame blend).
- **Chrome**: flat list tiles, uppercase panel labels, 8 px mono status chips,
  overlay shadow tokens (`PiRadius`, `PiType`, `GlassSurface`, `AssistantAvatar`
  in `lib/design/primitives.dart`).
- **Goldens** now load Roboto, JetBrains Mono and Material Icons from the SDK /
  bundled assets, so they verify real glyphs instead of Ahem boxes.

## Toolchain

Recorded 2026-11-03 on the build machine (macOS 26.5.1, build 25F80,
darwin-arm64).

| Tool | Version | Location |
|---|---|---|
| Flutter | 3.47.5, channel `stable`, framework `6a19cca564` (2026-09-17) | `/Users/hamishfromatech/develop/flutter` |
| Dart | 3.13.4 | bundled with Flutter |
| DevTools | 2.60.0 | bundled with Flutter |
| CocoaPods | 1.16.2 | system |
| Android SDK | 36.0.0 (platform android-36, build-tools 36.0.0) | `/opt/homebrew/share/android-commandlinetools` |
| JDK | OpenJDK 17.0.20.1 (Homebrew) | via `JAVA_HOME` |
| Xcode | **absent** — only Command Line Tools 16.4.0.0.1 | `/Library/Developer/CommandLineTools` |

`flutter`/`dart` are on `PATH` persistently via `~/.zprofile`
(`export PATH="$HOME/develop/flutter/bin:$PATH"`). Flutter 3.47.5 clears the
`flutter: '>=3.24.0'` constraint in `app/pubspec.yaml`.

`flutter doctor -v` (trimmed to the parts that carry information):

```
[✓] Flutter (Channel stable, 3.47.5, on macOS 26.5.1 25F80 darwin-arm64, locale en-US)
    • Flutter version 3.47.5 on channel stable at /Users/hamishfromatech/develop/flutter
    • Framework revision 6a19cca564 (7 weeks ago), 2026-09-17 14:13:22 -0400
    • Engine revision af7e796e16
    • Dart version 3.13.4
    • DevTools version 2.60.0

[!] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    • Android SDK at /opt/homebrew/share/android-commandlinetools
    • Platform android-36, build-tools 36.0.0
    • Java version OpenJDK Runtime Environment Homebrew (build 17.0.20.1+0)
    ! Some Android licenses not accepted. To resolve this, run: flutter doctor --android-licenses

[!] Xcode - develop for iOS and macOS
    ✗ Xcode installation is incomplete; a full installation is necessary for iOS and macOS development.
      Download at: https://developer.apple.com/xcode/
      Or install Xcode via the App Store.
      Once installed, run:
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
        sudo xcodebuild -runFirstLaunch
    • CocoaPods version 1.16.2

[✓] Chrome - develop for the web
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

[✓] Connected device (2 available)
    • macOS (desktop) • macos  • darwin-arm64
    • Chrome (web)     • chrome • web-javascript

[✓] Network resources

! Doctor found issues in 2 categories.
```

### Xcode blocker (unresolved — needs a human)

Full Xcode is not installed, and installing it needs App Store /
developer.apple.com access plus `sudo`, so it cannot be done from an agent run.
Exact state of the gate:

```
$ xcodebuild -version
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance

$ xcode-select -p
/Library/Developer/CommandLineTools

$ xcrun simctl list runtimes
xcrun: error: unable to find utility "simctl", not a developer tool or in PATH
```

Human steps, in order:

1. Install Xcode (App Store, or the `.xip` from developer.apple.com).
2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -runFirstLaunch`
4. `sudo xcodebuild -license accept` if the license prompt appears.

Until step 1 happens there is no `xcodebuild -version`, no iOS simulator, no
`flutter run -d ios`, no `pod install` in `app/ios`, and the Xcode signing flow
in `README.md` cannot be exercised. Analyze, `flutter test`, the web build and
the macOS desktop target are unaffected — the Dart toolchain does not need
Xcode. CI builds the unsigned IPA on a macOS runner instead
(`.github/workflows/ios.yml`), so iOS artifact production does not depend on
this machine.

## Verification (current)

Measured at HEAD `279f08f` on 2026-11-03:

```bash
cd app
flutter pub get     # Got dependencies!
flutter analyze     # No issues found! (ran in 1.2s)
flutter test        # 267 passing, 0 failing, 0 skipped, ~10 s
```

`flutter test` prints two `MissingPluginException(No implementation found for
method stop on channel dev.steenbakker.mobile_scanner/scanner/method)` lines
while the pairing screens tear down. That is logged noise, not a failure —
every test still reports `success`.

### Test-count reconciliation

The three counts in this repo are historical, not contradictory. Each was
re-measured by extracting that commit with `git archive` and running
`flutter test` in it:

| Source | Count | What it measured |
|---|---|---|
| `BUILD.md`, before this update | 215 | the tree when this file was written, 2026-10-25; that same day's commits `230df99` and `81e282d` already measured 217 |
| `README.md`, before this update | 244 | commit `1ac4bbd` (desktop parity), 2026-10-26 — 244 confirmed |
| HEAD `279f08f` | **267** | current — 267 confirmed |

`279f08f` closed the 244 → 267 gap (alerts, backdrop, cron run history):
`cron_alert_test`, `notification_service_test`, `cron_run_history_test`, plus
new `composer_send`, `user_echo` and `splash` cases. Goldens are the bulk of
the suite — 86 of the 267.

Release APKs are built at `app/build/app/outputs/flutter-apk/`
(`app-arm64-v8a-release.apk` ≈ 31 MB).

## CI

GitHub Actions, repository `hamishfromatech/a-coder-mobile` (private, default
branch `main`).

- `.github/workflows/mobile.yml` — `macos-26`, Flutter pinned `3.47.5`:
  `flutter analyze` + `flutter test --coverage`, uploads `lcov.info` and, on
  failure, golden diffs (14-day retention).
- `.github/workflows/ios.yml` — `macos-26` (Xcode 26 SDK is required by
  `connectivity_plus`), builds an unsigned IPA, uploads it for 14 days.
- Goldens are rasteriser-sensitive. `app/test/flutter_test_config.dart`
  tolerates ≤0.05% differing pixels so macOS point updates cannot make CI
  flaky; keep it small and regenerate goldens only on macOS 26.
- Both workflows have `permissions: contents: read` and concurrency
  cancel-in-progress.
- **Branch protection is not enabled**: it requires GitHub Pro for a private
  repo (or a public repo). See `plan/12-repo-hosting.md` §11.4.

## Remaining

1. **Device/E2E validation** — no simulator is available because full Xcode is
   not installed (see *Xcode blocker* above), and no Android emulator is
   configured. `app/integration_test/happy_path_test.dart` compiles and runs
   against the in-process fake bridge once a device is attached. The manual
   matrix in `QA.md` is unexecuted (including a TLS pairing pass).
2. **Push relay implementation** — design is in `plan/11-push-relay-spike.md`;
   nothing ships yet.
3. **Bridge branch** — `wss://` and hardening live on
   `feat/mobile-bridge-perf` (`0ccc0f288`); merge into the active CLI branch
   when ready.
4. **Repo hosting** — pushed to `github.com/hamishfromatech/a-coder-mobile`
   (private, `main`); CI green. Branch protection still needs GitHub Pro or a
   public repo (`plan/12-repo-hosting.md` §11.4).
