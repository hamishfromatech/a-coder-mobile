# A-Coder Mobile — QA & Test Guide

## Run commands
- Unit/widget/golden headless: `cd app && flutter pub get && flutter test test/support test/golden`
- Full suite: `cd app && flutter test`
- Analyze: `cd app && flutter analyze`
- Regenerate goldens: `cd app && flutter test --update-goldens test/golden`
- Integration (device/emulator): `cd app && flutter test integration_test` (requires a connected device; fake server binds 127.0.0.1 inside the test process)
- Read integration test help: `cd app && flutter test integration_test --help`

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

### Manual device matrix
| Check | iPhone (iOS 17+) | Android (13+) |
|---|---|---|
| QR pair | ✔ | ✔ |
| TLS (`wss://`) pair with pinned cert | pending | pending |
| Discovery list | ✔ (local network prompt) | ✔ |
| Streaming 10-min turn, screen off/on | resync ok | resync ok |
| Wi-Fi ↔ cellular switch | reconnect | reconnect |
| Kill/restore bridge | banner → resync | banner → resync |
| Approval card w/ 20s timeout | renders + answers | renders + answers |
| 2MB bash output tool card | no frame loss | no frame loss |
| Background 5min → foreground | resync < 2s | resync < 2s |
| Token persisted (app restart, no re-pair) | Keychain | Keystore |
| Rotate token → old client 401 | ✔ | ✔ |

## Known gaps requiring app/lib hooks (not implemented here)
- Injectable transport / secure-storage seam: full pairing→home→chat driving in
  `flutter test` is blocked by `HostRegistry`'s direct `FlutterSecureStorage`
  and `SharedPreferences` usage. The headless E2E exercises the transport
  protocol against the fake server but cannot pump the real `PairingScreen`
  flow without platform mocks.
- Chat bubbles (user/assistant/thinking), the approval card, the queue card and
  the jump-to-latest pill are now public and covered by deterministic goldens
  (`test/golden/components_golden_test.dart`, 390x844 dark/light).
- Home session row (`_SessionRow`) is private; empty state is covered via
  `EmptyState`.
- Settings screen sections were not made golden because they depend on shared
  prefs / secure storage; `SettingsScreen` remains untested.
- Pairing manual-form goldens emit a `MissingPluginException` during teardown
  because the scan tab instantiates `MobileScanner` without a platform impl
  in the test runner; the golden pixels are still produced and compared.
- Streaming/permission timing in integration tests relies on fake server
  scripted delays; UI-level approval swipe is verified manually per matrix.
EOF