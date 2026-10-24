# A-Coder Mobile

Flutter mobile client that pairs with a desktop bridge (`a-coder-cli serve`)
to remotely control and monitor the A-Coder AI coding agent — pair once, then
watch and drive your coding agent from anywhere on your LAN.

## Feature status (vs `plan/07-milestones.md`)

- ✅ M0–M2: bridge, discovery/pairing (QR + manual), connection layer
- ✅ M3 + M4 core: live transcript (markdown/code/thinking/tool cards),
  streaming (~16fps throttled), prompt/steer/follow-up, offline outbox,
  image attachments, approvals (swipe-to-allow / deny / always-allow),
  question/select/input/notify request UIs, session list + rename, model
  picker, compact/abort/export, background sessions
- 🚧 M5 polish (desktop settings card) and M6 extensions (cron, Office,
  wss://, push) — not started

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
flutter test          # 62 unit/widget tests (wire, connection, router, state)
flutter analyze       # 0 errors / 0 warnings
```
