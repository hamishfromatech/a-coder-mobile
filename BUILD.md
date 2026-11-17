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

- Protocol contract: [`app/lib/core/protocol/`](app/lib/core/protocol)
- Bridge: `a-coder-cli serve` in
  `../a-coder-cli/packages/coding-agent/src/serve/`
- App architecture: [`app/lib/`](app/lib)
- Screens: [`app/lib/features/`](app/lib/features)
- Test strategy + honest gap list: [`QA.md`](QA.md)

## Where things live

| Path | What |
|---|---|
| `app/` | Flutter client (all code + tests) |
| `QA.md` | Test commands, device matrix, known coverage gaps |
| `.github/workflows/mobile.yml` | CI: analyze + tests + coverage |
| `bridge/` | **Retired.** Canonical bridge lives in the CLI repo (see `bridge/README.md`) |

The bridge is now `a-coder-cli serve`:
`../a-coder-cli/packages/coding-agent/src/serve/` with tests in
`../a-coder-cli/packages/coding-agent/test/serve/`.

The build plan and specs (`plan/`) are kept on the development machine only and
are git-ignored; they are not part of this repository.

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
- **Push relay**: deferred post-v1 (board scope decision, 2026-11-17); v1 is
  LAN-only. The implementable design is kept current in
  `plan/11-push-relay-spike.md`; no relay client, APNs/FCM dependency, or
  notification permission prompt ships.

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
| Android SDK | 36.0.0 (platforms android-35 + android-36, build-tools 36.0.0) | `/opt/homebrew/share/android-commandlinetools` |
| Android emulator | 37.2.13.0 (build 16740729) | `/opt/homebrew/share/android-commandlinetools/emulator` |
| Android AVD | `acoder_pixel_api35` — Pixel 7, Android 15 (API 35), arm64-v8a | `~/.android/avd/` |
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

[✓] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    • Android SDK at /opt/homebrew/share/android-commandlinetools
    • Emulator version 37.2.13.0
    • Platform android-36, build-tools 36.0.0
    • Java version OpenJDK Runtime Environment Homebrew (build 17.0.20.1+0)
    • All Android licenses accepted.

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

Measured on 2026-11-03 at `361f747`:

```bash
cd app
flutter pub get     # Got dependencies!
flutter analyze     # No issues found! (ran in 2.1s)
flutter test        # 267 passing, 0 failing, 0 skipped, ~8 s
```

`flutter test` prints two `MissingPluginException(No implementation found for
method stop on channel dev.steenbakker.mobile_scanner/scanner/method)` lines
while the pairing screens tear down. That is logged noise, not a failure —
every test still reports `success`.

### Android emulator validation (2026-11-03)

Android toolchain is now complete on this machine: SDK 36 with `emulator`
37.2.13, a Pixel 7 / Android 15 (API 35) arm64-v8a AVD, and all licences
accepted. Setup commands are in [`QA.md`](QA.md#android-emulator-setup-2026-11-03).

```bash
flutter devices
# … sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 15 (API 35) (emulator)

cd app && flutter test integration_test -d emulator-5554
# Built build/app/outputs/flutter-apk/app-debug.apk
# 00:41 +1: happy path: prompt -> tool approval -> steer -> final answer
# 00:41 +1: All tests passed!
```

The integration suite passes on the emulator. The manual matrix in `QA.md` was
executed as far as the emulator allows: **1 pass** (token persisted across app
restart), **2 fails** (kill/restore bridge does not auto-resync and the offline
Retry button is a no-op; background 5 min → foreground lands on the Pairing
screen), and **7 not run** because they need a camera QR, mDNS through the
emulator NAT, a cellular radio, or a live model turn. The per-row evidence and
follow-ups are recorded in `QA.md`.

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

GitHub Actions, repository `hamishfromatech/a-coder-mobile` (**public**, default
branch `main`).

- `.github/workflows/mobile.yml` — `macos-26` for `flutter` (Flutter pinned
  `3.47.5`): `flutter analyze` + `flutter test --coverage`, uploads `lcov.info`
  and, on failure, golden diffs (14-day retention). A second `android` job runs
  on `ubuntu-latest`: `flutter build apk --debug`, which proves the Android app
  compiles without signing material.
- `.github/workflows/ios.yml` — `macos-26` (Xcode 26 SDK is required by
  `connectivity_plus`), builds an unsigned IPA, uploads it for 14 days. It now
  also triggers on PRs without a `paths:` filter; a cheap `changes` gate on
  `ubuntu-latest` decides whether the macOS build must run, so the check can
  never stay pending while Dart-only PRs do not spend macOS minutes.
- Goldens are rasteriser-sensitive. `app/test/flutter_test_config.dart`
  tolerates ≤0.05% differing pixels so macOS point updates cannot make CI
  flaky; keep it small and regenerate goldens only on macOS 26.
- All workflows have `permissions: contents: read` and concurrency
  cancel-in-progress.
- **Branch protection is enabled on `main`** (2026-11-03): required check
  `mobile / flutter` with up-to-date branches, 1 approving review, dismiss
  stale approvals, approval of the most recent push, conversation resolution,
  linear history, no force-push and no deletion, enforced for administrators.
  Direct pushes to `main` are therefore rejected for everyone. Required checks
  are `mobile / flutter`, `mobile / android` and `iOS build / unsigned-ipa`
  (added 2026-11-03 after both new jobs passed on `main` at `e56fed2`).
- Public-repo Actions minutes on standard runners are free, so the macOS 10×
  private-repo multiplier no longer applies.
- **`LICENSE` is MIT + A-Tech dual terms** (decided 2026-11-02T14:59:32Z), the
  same structure as `a-coder-cli`. `README.md` carries a short License section
  that defers to the full text (`LICENSE` is the authoritative copy).

## Remaining

1. **Device/E2E validation** — Android is now set up and the integration suite
   passes on the emulator (see *Android emulator validation* above). Two matrix
   rows failed on the emulator and need fixes before the matrix can be called
   green: the offline home's Retry button is a no-op, and the app does not
   resync after the bridge returns or after a long background. iOS still has no
   simulator because full Xcode is not installed (see *Xcode blocker* above),
   and the QR/discovery/cellular/live-turn rows still need a physical device.
2. **Push relay** — **deferred post-v1** by the board on 2026-11-17 (nothing
   past 2026-12-12; LAN-only path stays). `plan/11-push-relay-spike.md` now
   holds the implementable design (endpoints, HMAC registration, coalescing,
   dedupe, revocation) for the post-v1 milestone. Implementation requires a
   new milestone scope and explicit board approval; it is not started.
3. **Bridge branch** — `wss://` and hardening live on
   `feat/mobile-bridge-perf` (`0ccc0f288`); merge into the active CLI branch
   when ready.
4. **Repo hosting** — pushed to `github.com/hamishfromatech/a-coder-mobile`
   (**public**, `main`); CI green and branch protection enforced. The Android
   compile job, iOS PR guard, and `LICENSE` landed through PR #1 (squash
   `e56fed2`), because `main` no longer accepts direct pushes. All three CI
   checks are now required.
