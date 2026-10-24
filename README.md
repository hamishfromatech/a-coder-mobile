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
| [`plan/`](plan) | Complete build plan: architecture, wire protocol, bridge spec, screens, milestones, testing, design language |
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

## Verify

```bash
cd app
flutter analyze     # No issues found
flutter test        # 215 tests (unit, widget, goldens, fake-bridge E2E)
```

CI: [`.github/workflows/mobile.yml`](.github/workflows/mobile.yml).

## Product docs

- Protocol contract — [`plan/03-protocol-spec.md`](plan/03-protocol-spec.md)
- Bridge — [`plan/04-bridge-spec.md`](plan/04-bridge-spec.md)
- App architecture — [`plan/05-app-architecture.md`](plan/05-app-architecture.md)
- Screens — [`plan/06-screens-spec.md`](plan/06-screens-spec.md)

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
