# 04 — Engine Bridge Spec: `a-coder-cli serve`

The bridge is the only engine-side deliverable. It is a new subcommand in the
existing `coding-agent` package: TypeScript, Node ≥ 22, ESM, strip-only syntax
(matching repo rules — see `AGENTS.md`: no enums/namespaces/parameter
properties, top-level imports only, run `npm run check` after changes).

## 1. Contract summary

`a-coder-cli serve [options]`

```
Options:
  --cwd <dir>            project directory for the engine (default: process cwd)
  --port <n>             WebSocket port (default 8787, auto-pick +n if busy, announce actual)
  --bind <addr>          bind address (default 0.0.0.0; 127.0.0.1 for dev)
  --provider <id>        forwarded to engine
  --model <id>           forwarded to engine
  --continue             resume last session in cwd (forwarded)
  --token <secret>       reuse an existing pairing token (else generate + persist)
  --token-file <path>    accepted for CLI compatibility; the default store lives under the agent dir
  --max-clients <n>      concurrent control clients (default 1)
  --idle-exit <minutes>  stop serve + engine after N minutes with no client (default 30, 0 = never)
  --no-auth              tokenless mode (rejected unless --bind 127.0.0.1)
  --announce/--no-announce   mDNS announce (default on)
```

Startup output (human, to stderr — stdout stays reserved):

```
A-Coder serve listening on ws://192.168.1.20:8787
Pairing token: aB3d…9x (also shown as QR below)
mDNS: _a-coder._tcp announced as "Hamish's MacBook"
```

## 2. Module layout (inside `packages/coding-agent`)

```
src/serve/
├── serve-command.ts        // CLI wiring: flags, token persistence, banner, lifecycle
├── bridge.ts               // spawn engine + pump lines ↔ clients (the core)
├── ws-server.ts            // WebSocket server + auth + rate limit + client registry
├── pairing.ts              // token generation, QR payload, manual code chunks
├── announce.ts             // mDNS (multicast-dns or bonjour-service npm pkg)
└── control-frames.ts       // bridge→client envelopes ({"type":"bridge", …})
```

Registration point: the CLI command registry — find where `bench` is
registered as a subcommand (`packages/coding-agent/src/cli/bench-command.ts`,
wired in `src/main.ts` / `cli/index.ts`) and add `serve` alongside it.

Runtime deps to add (exact versions pinned at implementation time):
`ws` (WebSocket server), `qrcode` (terminal QR), `bonjour-service`
(pure-JS mDNS announce — avoids native deps), `nanoid` (optional). No other
new deps. All are pure JS and already compatible with the repo's install
rules (no lifecycle scripts).

## 3. Engine lifecycle

- Spawn engine exactly like the desktop (`client.rs::spawn` semantics):
  `[cli, "--mode","rpc", (--continue)?, (--provider P)?, (--model M)?]`,
  cwd, env PATH reconstructed (see `reconstructed_path()` semantics in
  client.rs — the bridge runs inside the CLI process; pass `process.env`
  through with no extra reconstruction when serving locally).
- **One client = one engine.** When the first authenticated client connects,
  spawn the engine if not running. When the last client disconnects, keep the
  engine for `--idle-exit` minutes (so brief signal loss doesn't kill a turn),
  then `SIGTERM` → 10s grace → `SIGKILL`.
- **Crash policy**: if the engine exits non-zero while a client is connected,
  emit `{"type":"bridge","event":"engine_exited","code":N}` and restart the
  engine **at most twice** (30s apart); then emit
  `{"type":"bridge","event":"engine_failed","attempts":2}` and stop.
- **Streaming turn survives disconnects**: because the engine is a separate
  process owned by the bridge, a dropped phone does not abort a run. On
  reconnect + resync the client catches up (doc 03 §7; doc 05 §6).
- **stderr**: pipe engine stderr to bridge stderr with a `[engine]` prefix
  (never to WS — it is not JSON).
- Shutdown: SIGTERM to bridge → emit bridge frame `shutting_down` → close WS
  cleanly → SIGTERM engine → 10s → SIGKILL. Also handle SIGINT identically.

## 4. Wire behavior

- WS text frames ↔ NDJSON lines 1:1 (doc 03 §1). Outbound: every engine stdout
  line is sent to **all authenticated clients** (v1 has 1, but write it
  fan-out ready). Inbound: serialize commands from clients to engine stdin via
  a single-writer queue.
- **Control frames** (bridge-owned, `type:"bridge"`): `connected {clients}`,
  `engine_exited {code}`, `engine_failed {attempts}`, `shutting_down`,
  `server_version {v}` (sent right after auth). Clients must parse and route
  them separately from engine events.
- **HTTP endpoints on the same port** (for discovery + pre-auth checks):
  - `GET /health` → `200 {"ok":true,"version":"<bridge version>"}`
  - `GET /info` → `200 {name, version, engineVersion?, requiresAuth:true,
    projects:[{name, cwd}], activeClients:n, maxClients:n}` — **before** auth
    this returns only `{requiresAuth:true}`; with a valid token it returns the
    full body (lets the app verify a token without opening a WS).
  - Upgrade path `/rpc` only; other paths → 404.
- **Auth**: on upgrade, read `Authorization: Bearer <token>` (fallback
  `?token=`, log a warning when used). Compare with timing-safe equality
  (`crypto.timingSafeEqual`). On failure: HTTP 401, count against rate limit
  (10 failures/15min/IP → 403 for 15min).
- **Backpressure**: if a client's socket buffers > 8 MiB (slow phone), drop
  that client (emit `bridge slow_client` to logs, close 1008). The engine's
  own backpressure handling (`waitForRawStdoutBackpressure`) continues to
  protect the engine regardless of clients.

## 5. Pairing & discovery

### 5.1 mDNS announce (bonjour-service)

- Service type: `_a-coder._tcp`, name: `A-Coder on <hostname>` (sanitized),
  port: WS port. TXT records: `v=1`, `path=/`, `tokenReq=1`, `name=<friendly>`,
  `engine=a-coder-cli`, `id=<machine-id>` (first 8 bytes of SHA-256 of the
  token, so the app can dedupe instances without leaking the token).
- Re-announce on `SIGHUP` (document for users) and on network-change detect
  (best effort).

### 5.2 QR pairing payload

The desktop shows the QR (M5 adds a settings card; until then `serve` prints a
terminal QR via `qrcode`). Payload (compact, versioned):

```json
{"v":1,"kind":"acoder","host":"192.168.1.20","port":8787,"tls":false,
 "token":"<44-char base64url>","name":"Hamish's MacBook","id":"a1b2c3d4"}
```

Manual-entry fallback: token rendered as 4 groups of 8 chars; host+port shown
as text. Scanning = trust: the QR contains the bearer token.

### 5.3 Pairing handshake (mobile side)

1. Scan QR (or discover via mDNS and fetch `/info`).
2. App stores `{host, port, token, name, id}` in secure storage; runs the
   connection state machine; on `ready` performs first resync; pairing done.
3. The bridge marks the issuing client as paired in a small registry file
   (planned: `~/.a-coder-cli/agent/serve/clients.json`: device name, last
   seen, added at) so the future settings UI can revoke devices. (Not
   implemented in v0.1 — token-level revoke only.)

## 6. Token persistence & revocation

- Default token file: `~/.a-coder-cli/agent/serve/token` (chmod 600; the
  bridge keeps all state under the agent dir, not `~/.a-coder/cli/serve`).
  `serve` reuses it; `--token` overrides; deleting the file + restart =
  revoke-all.
- `serve --rotate` regenerates the token, restarts engine connections, prints
  a new QR (v1: CLI flag only).

## 7. Explicit non-goals / deferred (with design hooks)

- `wss://` + self-signed cert (`--tls-cert/--tls-key` flags reserved).
- Cross-project switching (bridge restart with `--cwd`; the phone can offer
  "Restart engine in project X" via a future `bridge` command).
- Multi-client roles (`view` vs `control` tokens) — token *schema* already
  reserves this; v1 issues a single all-powerful pairing token.
- Push notification relay (needs a cloud component; N4).

## 8. Native/OS notes (both platforms)

- iOS Info.plist (app side, for discovery): `NSBonjourServices =
  ["_a-coder._tcp"]`, `NSLocalNetworkUsageDescription`, camera usage string;
  App Transport Security exception allowing `ws://` to private LAN IPs
  (`NSAllowsLocalNetworking = true`).
- Android: `INTERNET`, `ACCESS_NETWORK_STATE`; cleartext to LAN allowed via
  `networkSecurityConfig` (base-config cleartextTrafficPermitted=false +
  domain/system exception for local subnets) — document both files verbatim
  in the milestone M2 checklist.
- macOS desktop (for `serve` firewall): first run prompts to allow incoming
  connections; document in the desktop settings card (M5).

## 9. Acceptance criteria (bridge, gated in M1)

1. `a-coder-cli serve --bind 127.0.0.1 --no-auth` + the doc 03 §8 conformance
   script: all commands in the catalog round-trip; the §6 turn example
   replays 1:1 over WS.
2. Wrong token → 401, counted; 11th failure/15min → 403. Correct token → open.
3. Engine kill -9 → clients receive `bridge engine_exited`, engine restarts,
   client resyncs; twice-max enforced.
4. Phone on same LAN discovers the machine via `_a-coder._tcp` (bonsoir test
   on a real device or `dns-sd -B _a-coder._tcp` on macOS).
5. QR scan (mobile_scanner) parses and connects first try.
6. `serve` survives phone disconnect mid-turn; turn completes; reconnect
   resync shows the final transcript.
7. `npm run check` clean; unit tests for: token parsing, rate limiter, line
   splitter (U+2028 case), bridge pump (mock engine via a fake RPC script).