# A-Coder Mobile

Pair once with your desktop, then watch and drive the A-Coder coding agent from
your phone — over your own LAN, no cloud relay.

```
┌────────────────┐   WebSocket (Bearer)   ┌──────────────────────┐   stdio NDJSON   ┌──────────────────┐
│  Flutter app   │ ◄────────────────────► │  a-coder-cli serve   │ ◄──────────────► │  agent engine    │
│  iOS + Android │      ws://…/rpc        │  (desktop bridge)    │   --mode rpc     │  (coding agent)  │
└────────────────┘                        └──────────────────────┘                  └──────────────────┘
```

## What's in this folder

| Path | Description |
|---|---|
| [`app/`](app) | Flutter client — protocol, connection layer, chat, sessions, pairing, settings |
| [`QA.md`](QA.md) | How to run every test tier, the manual device matrix, and known coverage gaps |
| [`BUILD.md`](BUILD.md) | Current build status, verification numbers, and remaining work |
| [`bridge/`](bridge) | Pointer only — the bridge moved into the CLI repo |

The bridge is shipped as `a-coder-cli serve`:
`../a-coder-cli/packages/coding-agent/src/serve/`.

## Quick start (dev)

```bash
# 1. Desktop: start the bridge (prints a QR + pairing token)
cd ../a-coder-cli/packages/coding-agent && npm run build
a-coder-cli serve --port 8787

# 2. Phone/emulator: run the app
cd app && flutter pub get && flutter run
```

Scan the QR (or enter host/port/token on the Manual tab). Same Wi-Fi required
unless you use a VPN/Tailscale.

## iOS

The iOS project is configured and its pods resolve (`ios/Podfile`,
`ios/Podfile.lock`). A full **Xcode** installation is required to compile —
Command Line Tools alone are not enough:

```bash
# One-time: install Xcode from the App Store, then point the toolchain at it
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Build targets:

```bash
./scripts/build_ios.sh simulator   # app/build/ios/iphonesimulator/Runner.app
./scripts/build_ios.sh unsigned    # app/build/ios/unsigned.ipa (sign with Sideloadly/AltStore)
./scripts/build_ios.sh ipa         # signed .ipa (Xcode team required)
```

To run on your own iPhone from Xcode: open `app/ios/Runner.xcworkspace`, select
the Runner target → Signing & Capabilities, choose your personal team (a free
Apple ID works), then Run. The bundle id is `dev.acoder.mobile.acoderMobile`.

CI builds an unsigned IPA on a macOS runner:
[`.github/workflows/ios.yml`](.github/workflows/ios.yml) (workflow_dispatch or
push to `main`). Download the artifact and sign it with your Apple ID.

Local-network access, camera (QR), photo library (attachments) and Bonjour are
declared in `ios/Runner/Info.plist`; iOS prompts on first connect.

## Verify

```bash
cd app
flutter analyze     # No issues found
flutter test        # 267 tests (unit, widget, goldens, fake-bridge E2E)
```

CI: [`.github/workflows/mobile.yml`](.github/workflows/mobile.yml).

## Product docs

- Protocol contract — [`app/lib/core/protocol/`](app/lib/core/protocol)
- Bridge — `a-coder-cli serve` in `../a-coder-cli/packages/coding-agent/src/serve/`
- App architecture — [`app/lib/`](app/lib)
- Screens — [`app/lib/features/`](app/lib/features)

The detailed build plan, protocol spec, and design notes live in the `plan/`
folder **on the development machine only**; that folder is git-ignored and is
not part of this repository.

## Feature set

Chat (streaming, tools, approvals, queue, rewind, paged history, images),
sessions, models, pairing (QR/manual/discovery), settings, **Scheduled tasks**
and **Your Office** surfaces, and **`wss://` with certificate pinning**.

The visual language mirrors the desktop app (`desktop-app/DESIGN.md`): the same
13/11 px type scale, glass composer and user bubble, flat assistant rows with
the accent avatar, hairline tool cards, and flat dense lists.

## Security model

- The bridge binds to the LAN and requires a 256-bit bearer token; the QR only
  contains host/port/token. mDNS never bypasses authentication.
- Tokens live in the iOS Keychain / Android Keystore and are excluded from
  Android backups.
- Transport defaults to plaintext `ws://` on the LAN. `a-coder-cli serve
  --tls-cert/--tls-key` switches to `wss://`; the QR then carries the cert's
  SHA-256 pin and the app rejects a mismatched certificate. Off-LAN access
  still belongs on a VPN/Tailscale.

## License

Dual-licensed by The A-Tech Corporation PTY LTD, mirroring
[`a-coder-cli`](https://github.com/hamishfromatech/a-coder-cli):

- **Free** for individuals, solo founders, and businesses with less than
  USD $10M in total annual revenue — MIT, open source, forever.
- **The A-Tech Corporation License** required for organizations with
  USD $10M or more in annual revenue deploying A-Coder across departments and
  users. Contact [The A-Tech Corporation](https://theatechcorporation.com).

See [LICENSE](LICENSE) for full terms.
