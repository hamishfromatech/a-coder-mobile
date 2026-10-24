# A-Coder Bridge (WebSocket Bridge)

`@acoder/serve-bridge` — spawns `a-coder-cli --mode rpc` and exposes its NDJSON protocol over authenticated WebSocket with mDNS discovery and QR pairing.

## Quick Start

```bash
cd bridge
npm install
npm run build
node dist/serve-command.js serve --bind 127.0.0.1
# → A-Coder serve listening on ws://127.0.0.1:8787
# → Pairing token: aB3d...9x (also shown as QR below)
```

## Usage in `a-coder-cli` repo

This package is integrated as the `serve` subcommand inside `packages/coding-agent/`. The CLI wiring registers it alongside existing commands like `bench`.

### Integration point

1. Copy files from `src/serve/*` into `packages/coding-agent/src/serve/`
2. Register in the CLI command registry (see `packages/coding-agent/src/cli/bench-command.ts` for pattern)
3. Add dependencies: `ws`, `qrcode`, `bonjour-service`, `nanoid`

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌───────────────┐
│  WebSocket      │◄───►│   Bridge (this pkg)   │◄───►│ Engine        │
│  Clients (N)    │  WS  │                     │ stdio │ a-coder-cli  │
└─────────────────┘     │ - Token auth          │     │ --mode rpc    │
                        │ - Rate limiting       │     └───────────────┘
                        │ - mDNS announce      ▲
                        │ - Engine lifecycle   │
                        │ - Control frames     │
                        └──────────────────────┘
```

## CLI Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--cwd <dir>` | process.cwd() | Project directory for engine |
| `--port <n>` | 8787 | WebSocket port (auto-pick +n if busy) |
| `--bind <addr>` | 0.0.0.0 | Bind address (127.0.0.1 for dev) |
| `--provider <id>` | — | Forwarded to engine |
| `--model <id>` | — | Forwarded to engine |
| `--continue` | — | Resume last session |
| `--token <secret>` | — | Reuse existing pairing token |
| `--token-file <path>` | ~/.a-coder/cli/serve/token | Token persistence path |
| `--max-clients <n>` | 1 | Concurrent control clients |
| `--idle-exit <min>` | 30 | Stop after N min with no client (0 = never) |
| `--no-auth` | — | Tokenless mode (requires --bind 127.0.0.1) |
| `--announce/--no-announce` | on | mDNS announce `_a-coder._tcp` |

## Wire Protocol

See `plan/03-protocol-spec.md` for the complete wire contract. The bridge is a transparent transport — every WS text frame is one NDJSON line, 1:1 with engine stdio.

### Control frames (bridge-owned)

```json
{"type":"bridge","event":"connected","clients":1}
{"type":"bridge","event":"engine_exited","code":1}
{"type":"bridge","event":"engine_failed","attempts":2}
{"type":"bridge","event":"shutting_down"}
{"type":"bridge","event":"server_version","v":"0.1.0"}
```

## Security

- Bearer token auth on every WS handshake (Authorization: Bearer <token>)
- Rate limiting: 10 failures/15min per IP → 403 lockout for 15min
- `--no-auth` only allowed with `--bind 127.0.0.1`
- Token stored in file (chmod 600), never logged

## Testing

```bash
npm test           # Run vitest suite
./test.sh          # Install deps + run tests
```

### Test matrix
- **wire.test.ts**: LF-only framing, U+2028 safety, multi-MB lines
- **auth.test.ts**: Token accept/deny, rate limit lockout, QR payload round-trip
- **lifecycle.test.ts**: Spawn on first client, idle exit, crash-restart ≤2, clean shutdown
- **conformance.test.ts**: Full command catalog round-trip, extension_ui_request flow

## Acceptance Criteria (doc 04 §9)

1. ✅ `a-coder-cli serve --bind 127.0.0.1 --no-auth` + conformance script: all commands round-trip
2. ✅ Wrong token → 401, counted; correct token → open
3. ✅ Engine kill → clients receive bridge.engine_exited, engine restarts (max 2)
4. ⬜ Phone discovers via `_a-coder._tcp` (requires bonjour-service + real device test)
5. ⬜ QR scan parses and connects first try (requires mobile_scanner integration)
6. ✅ `serve` survives phone disconnect mid-turn; turn completes on reconnect
