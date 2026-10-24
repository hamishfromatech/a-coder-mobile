# 07 — Milestones (build in order)

Each milestone is a self-contained work package: **Goal → Tasks → Acceptance
criteria → Tests**. An implementing agent should complete one milestone, run
its gate, commit, and only then proceed. Estimated sizes assume one
implementing agent (LLM) with the plan folder as context.

---

## M0 — Bridge skeleton + stdio parity (engine side)

**Goal.** `a-coder-cli serve` exists, spawns the engine, and a WebSocket
client speaking doc-03 JSON can do a full turn.

Tasks:
1. Scaffold `src/serve/` per doc 04 §2; register the `serve` subcommand next
   to `bench` (see `packages/coding-agent/src/cli/`).
2. Token: generation (256-bit base64url), persistence (`~/.a-coder/cli/serve/token`,
   chmod 600), `--token` override, `--no-auth` guard (reject unless
   `--bind 127.0.0.1`).
3. WS server (`ws`): upgrade at `/rpc`, Bearer auth (timing-safe), 401 +
   rate limit (10/15min/IP → 403), `/health`, `/info` (pre/post auth shapes).
4. Engine pump: spawn `--mode rpc` (+ forwarded flags), NDJSON in/out,
   fan-out, single-writer stdin queue, stderr `[engine]` prefix.
5. Control frames: `connected`, `engine_exited`, `engine_failed`,
   `shutting_down`, `server_version` (post-auth).
6. Lifecycle: spawn-on-first-client, idle-exit timer, crash-restart (max 2),
   SIGTERM/SIGINT clean shutdown.
7. Unit tests: line splitter (U+2028, \r\n, multi-MB), rate limiter, auth
   (timing-safe), control frames, pump against a fake engine script.

**Accept.** Doc 04 §9 criteria 1–3 and 7 pass. `npm run check` clean.

---

## M1 — Discovery, pairing & conformance suite

**Goal.** Phone-independent proof that the bridge is discoverable, pairable,
and protocol-perfect.

Tasks:
1. mDNS announce via `bonjour-service` (`_a-coder._tcp`, TXT per doc 04 §5.1).
2. QR payload + terminal QR (`qrcode`) + manual code chunks (4×8).
3. Device registry file (`serve/clients.json`) write-through on first connect.
4. **Conformance suite** (`packages/coding-agent/test/serve/`): scripted
   WS client (Node `ws`) running doc 03 §8 checks 1–7 as vitest tests against
   a spawned `serve` (use `--bind 127.0.0.1 --no-auth` for most, token path
   for auth tests).

**Accept.** All conformance tests green in CI (`./test.sh` runs them; note the
repo's test rules — no e2e env needed for these). Manual: `dns-sd -B
_a-coder._tcp` sees the announce; `wscat -H "Authorization: Bearer <t>"` works.

---

## M2 — Flutter app skeleton + connection layer

**Goal.** `mobile-app/app/` Flutter project created; pairing by QR works;
connection machine reaches `ready` and stays resilient.

Tasks:
1. `flutter create` (org `dev.acoder.mobile`), configure lint
   (`flutter_lints`), CI-able `flutter analyze` clean.
2. `core/protocol/*` from doc 03 (models with freezed; wire codec with the
   U+2028 test).
3. `core/connection/*`: state machine (doc 02 §7.1), RpcClient with id
   correlation + per-command timeouts (15s/60s), ping, backoff w/ jitter.
4. Platform config: iOS ATS + Bonjour keys; Android cleartext + permissions
   (doc 04 §8) — exact XML in the milestone PR description.
5. Hosts registry (secure storage) + gate routing (`/` → pairing or home).
6. Unit tests: state machine transitions, backoff, rpc id matching,
   token storage round-trip (secure storage mock).

**Accept.** On a real device: scan the desktop QR (M1 bridge) →
`ready`; airplane-toggle reconnects; kill `serve` → banner; restart →
auto-resync. No `setState` spaghetti: all state through providers.

---

## M3 — Chat read path (the product becomes real)

**Goal.** Full transcript rendering parity with the desktop for reading.

Tasks:
1. Domain models + event router (doc 05 §4.1) with fixture tests from a
   **recorded session**: capture a real engine turn via the conformance client
   and commit it as a golden fixture (JSONL).
2. Transcript UI (doc 06 §3): user/assistant/thinking/toolResult rendering,
   markdown + code highlight, streaming replace-throttle (16/s).
3. Tool card framework + the table in doc 06 §4.3, starting with bash, read,
   write, then **edit with DiffView** (port EditDiff parser + tests).
4. App bar chips: model, thinking, permission mode, usage (turn_end).
5. Widget tests per card type + golden tests (dark/light).

**Accept.** Play a recorded turn into the UI (fixture replay provider) and
against the live engine; pixel-check against desktop screenshots; 60fps scroll
in profile mode on a mid-tier Android device with a 500-message session.

---

## M4 — Chat write path + approvals (the phone becomes a remote)

Tasks:
1. Composer: send/steer/follow-up logic from `sessionState.isStreaming`;
   images via picker/camera → `ImageContent`; buffered-unsent while offline.
2. Queue card (queue_update / queue_remove / clear_queue → restore-to-composer).
3. Approvals: permission card + question/select/input UIs + notify toasts
   (doc 06 §4.2), including Always-allow rules; exhaustive router tests.
4. Model picker screen; thinking/permission-mode chips; compact & abort
   (overflow); session switch/new from home; rename; background sessions
   sheet (get_sessions_status + sessions_update).
5. Integration tests (device/emulator): pair → prompt → see streaming →
   approve a bash tool → steer mid-turn → queue follow-up → verify delivery.

**Accept.** A real turn executed from the phone: prompt → approval granted →
steer → follow-up → final answer, with no desktop app running (bridge +
engine only).

---

## M5 — Desktop settings card + polish

Tasks:
1. Desktop (Tauri/React) Settings → new "Mobile access" card: serve status,
   start/stop, QR + manual token display (masked), connected device list
   (from doc 04 §5.3 registry), rotate token. This is React work in
   `desktop-app/` reusing `lib/rpc.ts` patterns — no engine changes.
2. Mobile polish: haptics on send/approve, pull-refresh everywhere, toasts
   audit, empty states, connection banner countdown, icons/splash.
3. Docs: `mobile-app/app/README.md` (run instructions), root plan README
   updated with "as-built" notes.

**Accept.** Desktop QR → phone connected end-to-end in < 30s (G1). Manual
device-matrix pass (doc 08 §5).

---

## M6 — Extensions (pick up only after M0–M5 fully green)

Ordered by value:
1. **Cron surface**: jobs list + runs from `cron_list/cron_runs` +
   `cron_update` events; run/pause/delete (`cron_run_now`, `cron_delete`).
2. **Your Office** (read-mostly): roster + huddle view from
   `office_update/office_huddle/office_activity`; send into huddles
   (`office_send`); errands list (no editor UI in v1).
3. **wss:// + pinned cert** (bridge flags from doc 04 §7).
4. **Push notifications** relay design spike only (doc 02 §7.3).

**Accept.** Each feature ships behind its feature flag with tests; removing
the flag must not touch chat-path code.