# A-Coder Mobile

Flutter mobile client that pairs with a desktop bridge (`a-coder-cli serve`)
to remotely control and monitor the A-Coder AI coding agent — pair once, then
watch and drive your coding agent from anywhere on your LAN.

## Feature status (vs `plan/07-milestones.md`)

- ✅ M0–M2: bridge (`a-coder-cli serve`), discovery/pairing (QR + manual +
  LAN discovery), connection layer with resync/backoff/auth handling
- ✅ M3 + M4: live transcript (markdown/code/thinking/tool cards, bounded
  markdown cache, jump-to-latest), streaming (~16 fps coalesced),
  prompt/steer/follow-up, offline outbox, image attachments, approvals
  (swipe-to-allow / deny / always-allow, countdown, expiry), question/select/
  input/editor/notify UIs, session list + rename/stop/delete, child-session
  badge, model picker, compact/abort/export, background sessions with abort
- ✅ M5: desktop "Mobile access" settings card (in `a-coder-cli/desktop-app`),
  haptics, icons/splash, empty/error states, accessibility pass
- 🚧 M6 extensions (cron, Office, wss:// + pinned cert, push) — behind flags
- 🚧 Chat polish backlog: long-press copy, tool-detail sheet, rewind,
  transcript pagination — see `../BUILD.md`

## Run (dev)

```bash
cd app
flutter pub get
# Desktop side, in another terminal:
#   acoder-serve --port 8787     (prints QR + token)
flutter run                       # pick a device/simulator
```

Pair by scanning the QR printed by the bridge (same Wi-Fi), or enter
host/port/token manually on the Manual tab.

## Android release builds

Signing uses `android/key.properties` + `android/app/upload-keystore.jks`
(both gitignored). If they don't exist, release builds fall back to the
debug keystore.

```bash
# Per-ABI (recommended for install — arm64 ≈ 30MB):
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (most modern phones)

# Fat APK (all ABIs):
flutter build apk --release

# Install over adb:
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Requirements on the build machine:

- JDK 17: `brew install openjdk@17` and
  `export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- Android SDK: `brew install --cask android-commandlinetools`, then
  `sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"`
  with `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`
  (`android/local.properties` records `sdk.dir`).

## Regenerating icons / splash

Brand assets live in `assets/icon/`. After editing them:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Architecture (doc 05)

`UI → State (Riverpod) → Domain (event router, pure) → Transport (RpcClient)
→ Platform (WS/secure storage)`. All inbound protocol events flow through the
pure reducer in `lib/features/chat/providers/event_router.dart`; screens never
hold protocol state. Connection resilience (backoff, ping, resync) lives in
`lib/core/connection/connection_manager.dart`.

## Tests

```bash
flutter test          # 130 tests (unit, widget, goldens, fake-bridge E2E)
flutter analyze       # No issues found
```

Golden tests: `flutter test test/golden`.
Integration harness (needs a device/emulator): `flutter test integration_test`.
See [`../QA.md`](../QA.md) for the device matrix and known coverage gaps.
