# 02 — System Architecture & Decisions

## 1. The system

```
┌───────────────────────────┐        ┌─────────────────────────────────────────┐
│  iPhone / Android          │        │  Desktop / home server                  │
│  A-Coder Mobile (Flutter)  │        │                                         │
│                            │        │  ┌───────────────────────────────────┐  │
│  ConnectionManager         │◄─ws───►│  │ a-coder-cli serve  (BRIDGE, M0/M1)│  │
│  - pairing (QR/mDNS)       │  WSS/WS│  │  - token auth + pairing           │  │
│  - NDJSON over WS          │        │  │  - mDNS announce _a-coder._tcp    │  │
│  - reconnect + resync      │        │  └──────────────┬────────────────────┘  │
└───────────────────────────┘        │                 │ spawn, NDJSON stdio    │
                                     │  ┌──────────────▼─────────────────────┐  │
                                     │  │ a-coder-cli --mode rpc  (ENGINE)   │  │
                                     │  │  sessions, tools, LLM providers,   │  │
                                     │  │  permissions, approvals            │  │
                                     │  └────────────────────────────────────┘  │
                                     └─────────────────────────────────────────┘

Same machine (v1): bridge and engine on the same host, bridge spawns engine.
Remote LAN (v1): phone ↔ bridge directly over Wi-Fi (or Tailscale IP).
Remote off-LAN (v1, zero-code): Tailscale/VPN — user enters the tailnet
  address as the host. Cloud relay: future phase (N4).
```

## 2. Transport decision — bridge process (chosen) vs in-engine server

### Option A (chosen): `a-coder-cli serve` — an out-of-process bridge

A new subcommand in the existing `coding-agent` package. The bridge:

1. Spawns the engine exactly like the desktop does
   (`a-coder-cli --mode rpc`, cwd, PATH reconstruction — copy the semantics of
   `desktop-app/src-tauri/src/rpc/client.rs::spawn`).
2. Hosts a WebSocket server that speaks **the same NDJSON protocol** as the
   engine's stdio: each WS text frame is one JSON line; each JSON line from the
   engine is one WS frame. No translation of payloads, only transport.
3. Adds what stdio never needed: token auth, pairing, mDNS announce,
   multi-client policy (v1: one active control client at a time), engine
   lifecycle (auto-restart on crash, idle shutdown), and a tiny HTTP GET
   `/health` + `GET /info` for discovery.

Why chosen:
- **Zero regression risk** to the existing stdio RPC path that the desktop
  depends on. The bridge is additive, isolated, and testable
  (spawn engine, drive it with the conformance suite from doc 08).
- One deliverable the LLM can build completely from this folder's specs
  without refactoring the 1,500-line `rpc-mode.ts`.
- The wire format is *identical* to stdio, so the mobile protocol layer and
  the desktop's `lib/rpc.ts` stay conceptually one contract.
- The bridge can be extended later (TLS, relay mode, multi-session fan-out)
  without touching the engine.

### Option B (rejected for v1): `--rpc-server` inside the engine

Refactor `runRpcMode()` into transport-agnostic core + stdio/WS adapters.
Rejected because it touches the most critical file in the product that the
desktop depends on; the refactor's benefit (one fewer process) does not
justify the regression risk. **Revisit only if** the bridge proves limiting
(e.g. multi-client fan-out demand).

## 3. Framework decision — Flutter (chosen)

Requirement: one app, iOS + Android, built largely by an AI coding agent.

| Criterion | Flutter | Native ×2 (SwiftUI + Compose) | Expo/RN (existing prototype) |
|---|---|---|---|
| Build effort for this app | 1 codebase, Dart is very LLM-productive | 2 full apps, 2 platforms to keep in sync | 1 codebase, but stack is being abandoned |
| WebSocket + JSON streaming | first-class (`web_socket_channel` + streams) | fine (URLSession / OkHttp) | fine |
| Long-lived state machine (connection, message accumulation) | Riverpod notifiers; predictable | fine | fine |
| Secure storage / Keychain / Keystore | `flutter_secure_storage` (Keychain, Keystore) | native APIs | RN keychain libs |
| mDNS discovery | `bonsoir` (Bonjour + NSD under the hood) | NWBrowser / NsdManager ×2 | react-native-zeroconf (aging) |
| QR scan + render | `mobile_scanner`, `qr_flutter` | AVFoundation / ML Kit ×2 | vision-camera (config heavy) |
| Markdown + code highlight + diff rendering | `flutter_markdown_plus`/`markdown_widget`, `flutter_highlight`, custom diff rows — all mature | ×2 implementations | the prototype's viewers exist but stack abandoned |
| App lifecycle correctness (doc 01 §6) | `WidgetsBindingObserver`, well-documented states | native lifecycle ×2 | similar |
| Performance feel | nativecompiled, more than adequate for a chat client | best | good |
| Risk | single: Dart skill ceiling (low for LLMs) | double implementation & maintenance | stack mismatch, prototype targets fiction |

Decision: **Flutter** (stable channel ≥ 3.24). Dart code is highly
constrained and deterministic to generate; the package ecosystem covers every
requirement with maintained, popular plugins (pinned list in doc 09). The
protocol layer is pure Dart with zero platform channels, so the app is ~99%
Dart — the riskiest part (native integration) is tiny and listed in doc 04 §8.

If a future native push-notification relay arrives, it plugs in via a thin
platform channel, documented as an extension point (§7.3) — not a reason to
go native now.

## 4. Connection topologies

| Topology | When | How |
|---|---|---|
| Same Wi-Fi / LAN | primary | `ws://<lan-ip>:<port>` discovered via mDNS or QR |
| Same machine loopback (dev) | dev/testing | `ws://127.0.0.1:8787` |
| Remote | user has Tailscale/VPN | same as LAN, but host = tailnet IP/name; no code difference |
| Cloud relay | future (N4) | bridge dials out to relay; phone dials relay; end-to-end token; not built in v1 |

Non-goal: hole-punching/NAT traversal in v1.

## 5. Multi-machine, multi-session model

- The app stores **multiple machines** (paired hosts). One is "active".
- The engine is **one project (cwd) per engine process** — the bridge spawns
  the engine bound to the directory configured at pair/serve time. Project
  switching = the desktop's model: `list_sessions` + `switch_session` work
  within the engine's cwd; cross-project is v2 (bridge restart with new cwd;
  note in doc 04 §7).
- Within a machine: sessions are switched over RPC (`switch_session`,
  `new_session`, `get_tree`), and detached/background sessions are observable
  via `get_sessions_status` / `sessions_update` events.

## 6. Security model (hard requirements)

1. **Token auth, always.** The bridge generates a 256-bit pairing token at
   first `serve`. Every WS handshake must present it (header
   `Authorization: Bearer <token>`; if header impossible, `?token=` query is
   accepted but discouraged and logged). Wrong/missing token → HTTP 401 and
   close. Rate-limit handshake attempts (10/min/IP, exponential lockout).
2. **Bind policy.** Default bind `0.0.0.0` is allowed **only** because every
   connection requires the token; offer `--bind 127.0.0.1` for USB-tunnel dev
   and document `--bind <tailscale-ip>`. Never run without a token; `--no-auth`
   exists only with `--bind 127.0.0.1` for tests.
3. **Token storage on phone**: Keychain (iOS) / EncryptedSharedPreferences-
   backed Keystore via `flutter_secure_storage`. Never logged. Never in
   screenshots (mask in settings UI).
4. **Pairing flow**: token is displayed *only* inside the QR (and as 8-char
   chunks for manual entry) in the desktop `serve` console / (M5) desktop
   settings card. QR payload is JSON, versioned (doc 04 §5).
5. **Approval surfaces are privileged.** `extension_ui_request` with
   `kind: "permission"` grants tool execution. The mobile app must:
   - show tool name + full args + cwd before Allow;
   - never auto-respond to any `extension_ui_request`;
   - on connection loss with pending approvals, re-fetch state and re-render
     pending approval UI from the engine's re-emit (engine re-emits pending
     request on `get_state` — verify in M1 conformance test; if not, keep
     pending map client-side and mark "unknown — check desktop").
6. **Transport**: `ws://` on LAN + token is v1-acceptable (token never leaves
   the LAN in plaintext form beyond it). `wss://` with a self-signed cert +
   pinned cert is the v1.5 hardening; Tailscale gives encrypted transport with
   zero code. **Cloud relay (future) must be end-to-end token + wss.**
7. **Principle of least surface**: the bridge exposes ONLY the engine protocol
   — no arbitrary file endpoints, no shell. Everything the phone can do is a
   command the desktop could send.

## 7. Cross-cutting behaviors

### 7.1 Reconnection & resync (the most important behavior)

State machine: `disconnected → connecting → authenticating → ready`, with
`reconnecting (attempt N, backoff)` side state.

- On any disconnect: exponential backoff 1s → 2s → 4s → 8s → 15s (cap 15s),
  reset on success. Jitter ±20%.
- On `ready` after reconnect: send `get_state` → `get_messages` →
  `get_sessions_status`; diff message list by length; if server
  `messageCount < local`, drop tail; if greater, fetch and replace. Show a
  "reconnected — resyncing" banner, not an error.
- Network changes (Wi-Fi↔cellular): Connectivity Plus triggers immediate
  reconnect attempt (cancel backoff).
- App resume from background: cancel backoff, connect immediately, resync.
- 30s inactivity ping: client sends `get_state` ping (lightweight) if no
  inbound line for 30s while `ready`; 2 missed → reconnect.

### 7.2 Idempotency & command safety

- All commands carry a client-generated `id` (UUID v4). Responses correlate by
  `id`. Unmatched responses are logged and dropped (same as desktop client.rs).
- Send timeout per command: 15s default; `get_messages`/`export_*`: 60s
  (parity with desktop `client.rs`).
- Never queue commands while `!ready`; the UI disables send and shows state.

### 7.3 Future extension points (document, don't build)

- `wss://` + pinned self-signed cert (bridge flag `--tls-cert/--tls-key`).
- Cloud relay: same protocol, different URL; token remains end-to-end.
- Push notifications: bridge keeps a per-device registration list; a small
  relay (FCM/APNs) pushes "approval waiting" / "turn finished" — the app then
  reconnects and resyncs. The v1 UI already surfaces everything needed.
- Multi-client fan-out: bridge allows N read-only viewers + 1 controller
  (design the token roles now: `pairing`, `control`, `view` — v1 issues only
  `pairing`=full control).

## 8. Repository layout for the mobile deliverable

```
mobile-app/
├── plan/                  ← this folder (spec + milestones)
├── bridge/                ← M0 deliverable: TypeScript bridge package
│   (published as a new CLI subcommand inside ../a-coder-cli/packages/coding-agent —
│    see doc 04 §3 for exact integration point; this folder holds only
│    its standalone test harness + fixtures during development)
└── app/                   ← M2+ deliverable: Flutter project (created in M2)
    ├── lib/               ← production Dart (tree in doc 05 §3)
    ├── test/              ← unit + widget + conformance tests (doc 08)
    └── integration_test/  ← device tests
```

The old `A-Coder-Mobile/` Expo project stays untouched (reference only) and
can be archived/deleted after M3 ships.