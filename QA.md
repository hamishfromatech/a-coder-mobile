# A-Coder Mobile — QA & Test Guide

## Run commands
- Unit/widget/golden headless: `cd app && flutter pub get && flutter test test/support test/golden`
- Full suite: `cd app && flutter test`
- Analyze: `cd app && flutter analyze`
- Regenerate goldens: `cd app && flutter test --update-goldens test/golden` (macOS 26 + Flutter 3.47.5 only — see *Golden baselines vs host OS*)
- Integration (device/emulator): `cd app && flutter test integration_test -d emulator-5554` (requires a connected device; fake server binds 127.0.0.1 inside the test process)
- Read integration test help: `cd app && flutter test integration_test --help`

### Android emulator setup (2026-11-03)

```bash
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

# One-time: emulator package + Android 15 (API 35) arm64 system image
sdkmanager "emulator" "system-images;android-35;google_apis;arm64-v8a"
avdmanager create avd -n acoder_pixel_api35 \
  -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7 --force

# Boot headless. The default 2 GB heap crashed twice during long E2E runs;
# 4 GB was stable for boots and test installs.
emulator -avd acoder_pixel_api35 -no-window -no-audio -no-boot-anim -no-snapshot \
  -memory 4096 -gpu swiftshader_indirect &
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 5; done
flutter devices   # sdk gphone64 arm64 • emulator-5554 • Android 15 (API 35)
```

Pair without the QR camera using the debug seed (the emulator reaches the host
loopback as `10.0.2.2`):

```bash
flutter run -d emulator-5554 \
  --dart-define=SEED_HOST_IP=10.0.2.2 \
  --dart-define=SEED_HOST_PORT=8787 \
  --dart-define=SEED_HOST_TOKEN=<token printed by `a-coder-cli serve`>
```

## CI compile coverage
- `mobile / flutter` (macOS, Flutter `3.47.5`) — analyze + the full test suite.
- `mobile / android` (`ubuntu-latest`) — `flutter build apk --debug`, a compile
  check that needs no signing material.
- `iOS build / unsigned-ipa` (macOS, Xcode 26) — unsigned IPA. On PRs a
  `changes` gate skips the macOS build unless iOS-native, plugin/dependency, or
  Dart paths changed; a skipped job reports success, so the check never pends.
- Branch protection on `main` requires `mobile / flutter`, `mobile / android`
  and `iOS build / unsigned-ipa`, plus one approving review, with up-to-date
  branches and no direct pushes.

## Test matrix
### Unit & Widget
- Wire codec, event router fixtures, connection state (existing `test/`).

### Golden
- Deterministic component goldens under `app/test/golden/` with real fonts
  loaded by `test/support/load_fonts.dart` (SDK Roboto + Material Icons +
  bundled JetBrains Mono); `disableAnimations` set in the harness.
- Sizes: 320x640, 390x844, 430x932; dark + light.

### Golden baselines vs host OS (policy settled 2026-11-17)

**Baselines are owned by macOS 26.** CI runs the golden job on `macos-26` with
Flutter pinned `3.47.5` (`.github/workflows/mobile.yml`), and the PNGs under
`app/test/golden/` are what that job produced. Regenerate them only there.

The build host was upgraded from macOS 26.5.1 to **macOS 27.2 (26B123)** and
nine golden cases drifted by 0.053–0.084 % of pixels (142–242 px per frame).
The drift is the rasteriser, not the branch: `main` at `74a0bc1` in a clean
`git worktree` fails the same files with identical counts, and the two
`pairing_manual` baselines regenerated here on 2026-11-04 drift too.

Measured 2026-11-17 on macOS 27.2 (26B123), Flutter 3.47.5 — the nine cases
that crossed the old 0.05 % budget and failed:

| Golden | Diff px | % | max Δ/channel | px Δ>16 | specks |
|---|---|---|---|---|---|
| approval_card_390x844_dark | 192 | 0.058 | 39 | 6 | 123 |
| approval_card_390x844_light | 192 | 0.058 | 42 | 7 | 123 |
| empty_state_320x640_dark | 142 | 0.069 | 12 | 0 | 102 |
| empty_state_320x640_light | 173 | 0.084 | 14 | 0 | 103 |
| empty_state_390x844_light | 173 | 0.053 | 14 | 0 | 103 |
| pairing_manual_390x844_dark | 194 | 0.059 | 29 | 3 | 134 |
| pairing_manual_390x844_light | 195 | 0.059 | 30 | 6 | 134 |
| session_row_populated_390x844_dark | 242 | 0.074 | 34 | 6 | 151 |
| session_row_populated_390x844_light | 242 | 0.074 | 28 | 4 | 148 |

Every differing pixel sat within 1 px of a >24/255 luminance edge, and the
diffs formed 102–151 disconnected specks (largest 28 px): text antialiasing,
not layout or colour. For contrast, shifting any of these frames by a single
pixel changes 1,642–4,422 pixels by >16 — 10–27× the budget, in connected runs.

The drift is wider than the failures suggested: 39 further goldens drift by
0.007–0.049 %, under the old budget and therefore silently accepted. Across all
48 affected goldens no frame has more than 7 pixels above Δ16 and none has a
pixel at Δ64.

**Baseline provenance — `session_row_populated_*` (THE-46):** the two session
row baselines were produced on this **macOS 27.2** build host on 2026-11-03/04,
not on `macos-26`. They are exactly the frames listed in the drift table above
(242 px / 0.074 % each), which the comparator accepts as host antialiasing
jitter, so the suite is green here and expected green in CI. Under the policy
below they are still off-host baselines and need one `macos-26` regeneration
pass (Flutter 3.47.5) at the next baseline refresh; do not refresh them with a
local `--update-goldens`. The `ListTile` title/subtitle Roboto pin added for
these goldens lives in the test harness only; production theming and rendering
are unchanged.

**Policy** (`app/test/support/golden_comparator.dart`):

- Pixels whose largest channel delta is ≤ 16 count as antialiasing noise.
- Pixels above 16 must stay within 0.05 % of the frame (the long-standing
  budget), and all differing pixels within 0.25 % of it.
- Any pixel at Δ≥64 fails outright.

Calibration tests (`app/test/support/golden_comparator_test.dart`) pin the
behaviour: a 1 px layout shift, a broad low-contrast tint, a single gross
pixel and excessive low-delta noise all still fail.

**If your host is not macOS 26:** run `flutter test` normally. Accepted drift
prints `Golden "….png": GoldenDiffStats(…) — accepted as host antialiasing
jitter` and the suite stays green. If a golden still fails:

1. Inspect `app/test/golden/failures/`: `*_isolatedDiff.png` shows the changed
   pixels, `*_maskedDiff.png` overlays them on the baseline.
2. A moved box, a colour change or a different glyph is a real regression.
   Fix the code; do not accept it.
3. If it is host drift beyond the bounds above, record the measurement in the
   commit and change the thresholds deliberately in the same change. Do not
   run `--update-goldens` off the baseline host: refreshing baselines on a
   non-macOS-26 host moves the mismatch into CI.

**Regenerating baselines** (macOS 26 + Flutter 3.47.5 only):

```bash
cd app && flutter test --update-goldens test/golden
```

### On-device LFM3 (branch `feat/on-device-lfm3`)

Automated coverage (headless, no model or device needed):

| Area | Test |
|---|---|
| Download-progress typing (`int` → `double`) | `test/features/local/local_chat_state_test.dart` |
| Thinking split: inline thinking-close marker, channel thinking, no marker | same file |
| Transcript round-trip + legacy entries without `thinking` | `test/features/local/local_transcript_test.dart` |
| Model catalogue specs (files, `mmproj`, URLs, license) | none — compile-time constants only |

Not covered automatically, by design: loading a real GGUF, generation,
LFM3 TTS, model download/import I/O, the recorder, and the OS permission
prompts. Those need a physical arm64 device with the model files (THE-48):

| Check | Expected |
|---|---|
| Import Omni (`gguf` + `mmproj`) then load | model loads, first token < 10 s on a recent phone |
| Text turn | streaming text, collapsible Thinking, markdown + code copy |
| Voice turn (first mic tap) | Android/iOS permission prompt, 16 kHz recording, Cancel/Send, text answer + speech |
| Image turn | gallery pick, caption preview, answer describes the image |
| Speech language switch | reply speech changes language; setting survives restart |
| Restart app | transcript restored; reloading the model re-feeds prior turns |
| Delete model from the hub | both files removed, hub shows not installed; the transcript survives hub deletion (only the chat screen's delete and New chat clear it) |
| Thermal / battery / tokens per second | recorded for the release notes; no throttling cliff in a 10-minute chat |

### Integration
- Happy path in `app/integration_test/happy_path_test.dart` against the fake
  bridge server.

### Bridge (CLI `serve`) checks
Recorded 2026-11-03 against CLI merge `dad9a9dbc` (source `0ccc0f288`,
`feat/desktop-unified-release`):

- `cd packages/coding-agent && npm test -- test/serve` — 11 files passed,
  1 skipped; 55 tests passed, 4 skipped.
- `npx tsgo --noEmit` — clean; `biome check` on the changed `src/serve` files —
  clean.
- TLS wiring smoke (`node src/cli.ts serve --bind 127.0.0.1 --port 8799
  --no-auth --no-announce --tls-cert test/serve/fixtures/tls-cert.pem
  --tls-key test/serve/fixtures/tls-key.pem`): banner printed `wss://` + the
  SHA-256 pin, `https://…/health` returned 200, a `wss://` client connected,
  spawned the engine, and answered `{"type":"get_state"}`.
- App side: `cd app && flutter analyze` — no issues; `flutter test` —
  267 tests passed.

Still manual: pairing the Flutter app on a physical device over `wss://` and
completing one turn (below).

### Manual device matrix — Android (executed 2026-11-03)

Run against app `1.0.0+1` (debug, arm64), **Android 15 / API 35**, Pixel 7 AVD
`acoder_pixel_api35`, bridge `a-coder-cli serve` 0.80.193 on the host. iOS is
still unexecuted — it is blocked on full Xcode (THE-38). The iOS pre-flight
below is the part that can be checked without Xcode.

| Check | Result | Evidence / reason |
|---|---|---|
| QR pair | not run | The emulator has no camera for the terminal QR; pairing was exercised through the manual-entry path and the `SEED_HOST_*` debug seed. The scanner itself is covered by widget goldens only. |
| TLS (`wss://`) pair with pinned cert | not run | Same as above; needs a real camera or a manual-entry pass. |
| Discovery list | not run | The emulator's NAT does not forward the host's mDNS (`_a-coder._tcp`), so the list cannot populate from this AVD. Needs a physical device on the LAN. |
| Streaming 10-min turn, screen off/on | not run | Needs a live model turn against the bridge; no provider was configured for this run. |
| Wi-Fi ↔ cellular switch | not run | The AVD has no cellular radio; airplane/Wi-Fi toggles do not exercise the reconnect-on-network-change row. |
| Kill/restore bridge | **FAIL** | Killing the bridge renders the offline state (red dot, "Offline — reconnect to load sessions"). After the bridge restarted the app did **not** reconnect within 55 s, and the **Retry button is a no-op** — `onRetry: _noop` at `lib/features/sessions/screens/home_screen.dart:366`. |
| Approval card w/ 20s timeout | not run | Needs a live permission-gated tool call from a real engine turn. |
| 2 MB bash output tool card | not run | Same — needs a live engine turn emitting 2 MB of tool output. |
| Background 5min → foreground | **FAIL** | After 5 minutes backgrounded the app returned to the **Pairing screen**, not a resynced home; reproduced after a cold emulator restart too. The emulator also died twice during this session (2 GB heap), so re-run on the 4 GB profile and a physical device before treating this as purely an app defect. |
| Token persisted (app restart, no re-pair) | **PASS** | `adb shell am force-stop` + relaunch reconnected to the same host with no re-pairing; the token survived in Android Keystore. |
| Rotate token → old client 401 | not run | Not reached — the emulator crashed before this row could be executed. |

**Follow-ups from the two failures** (not fixed here; this task is validation):

1. `ErrorState.onRetry` on the offline home is wired to `_noop`, so the user has
   no manual recovery path. Wire it to a forced reconnect/resync.
2. Auto-resync after the bridge returns did not resume within a minute even
   though the backoff chain in `ConnectionManager._scheduleReconnect` is
   unbounded on paper. Needs a device-side debug pass.
3. Background → foreground landed on the Pairing screen instead of resyncing;
   confirm on the 4 GB emulator profile and on a physical device.

### iOS device matrix — pre-flight only (2026-11-17)

Nothing below has been executed: it needs full Xcode (THE-38) and a physical
device. The static half is done, so a device run should not fail on a missing
`Info.plist` string:

- `app/ios/Runner/Info.plist` declares `NSCameraUsageDescription`
  (`mobile_scanner`), `NSPhotoLibraryUsageDescription` (`image_picker`),
  `NSMicrophoneUsageDescription` (`record` — added 2026-11-17),
  `NSLocalNetworkUsageDescription`, `NSBonjourServices` (`_a-coder._tcp`) and
  `NSAppTransportSecurity → NSAllowsLocalNetworking`.
- `plutil -lint app/ios/Runner/Info.plist` passes.
- Deployment target `15.0`; bundle id `dev.acoder.mobile.acoderMobile`.
- `app/ios/Podfile.lock` has no `record` pod yet; the first `pod install` after
  Xcode is installed regenerates it. Expect that before the first build — it is
  not a failure.

| Check | Expected | Status |
|---|---|---|
| Voice message: first mic tap | iOS permission prompt appears, recording starts, no app termination | not run |
| Voice message: mic denied | `Microphone permission is required` snackbar, no crash | not run |
| QR pair | camera prompt, scan pairs the host | not run |
| Discovery | host appears via `_a-coder._tcp` on the LAN | not run |
| `ws://` LAN connect | permitted by `NSAllowsLocalNetworking` | not run |
| Signed archive installs on device | archive + provisioning complete | not run |
| TestFlight upload | uploads; App Store Connect asks export compliance (`ITSAppUsesNonExemptEncryption` unset) | not run |

## Known gaps requiring app/lib hooks (not implemented here)
- Injectable transport / secure-storage seam: full pairing→home→chat driving in
  `flutter test` is blocked by `HostRegistry`'s direct `FlutterSecureStorage`
  and `SharedPreferences` usage. The headless E2E exercises the transport
  protocol against the fake server but cannot pump the real `PairingScreen`
  flow without platform mocks.
- Chat bubbles (user/assistant/thinking), the approval card, the queue card and
  the jump-to-latest pill are now public and covered by deterministic goldens
  (`test/golden/components_golden_test.dart`, 390x844 dark/light).
- Home session row is a public `SessionRow`
  (`app/lib/features/sessions/widgets/session_row.dart`) with 390x844
  dark/light goldens and widget tests in
  `test/golden/session_row_golden_test.dart`; `HomeScreen`'s empty-list copy is
  asserted in `test/features/sessions/home_screen_test.dart`, and the generic
  `EmptyState` golden still covers the visual.
- Settings screen sections were not made golden because they depend on shared
  prefs / secure storage; `SettingsScreen` remains untested.
- Pairing manual-form goldens emit a `MissingPluginException` during teardown
  because the scan tab instantiates `MobileScanner` without a platform impl
  in the test runner; the golden pixels are still produced and compared.
- Streaming/permission timing in integration tests relies on fake server
  scripted delays; UI-level approval swipe is verified manually per matrix.
EOF