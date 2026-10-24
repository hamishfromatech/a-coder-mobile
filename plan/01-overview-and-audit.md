# 01 — Overview & Current-State Audit

## 1. Product vision

A-Coder is an AI coding agent (CLI + desktop app) that edits real repos on the
user's machine. The mobile app turns a phone into a **remote control and
monitor** for that agent:

1. **Pair once** with the machine running the A-Coder engine (scan a QR code in
   the desktop app's settings, or pick it from the local network).
2. **Watch work happen**: streaming assistant responses, tool calls with
   diffs/stats, approvals that can be granted from the phone.
3. **Drive the agent**: send prompts, steer mid-turn, queue follow-ups, switch
   sessions/projects, abort, compact, change model & thinking level.
4. **Stay informed**: background sessions, scheduled tasks (cron), Your Office
   coworkers, task graph, queue state — all live-updating.
5. Work from anywhere: same Wi-Fi direct connection; Tailscale/VPN for remote;
   an optional hosted/cloud relay comes later (out of scope for v1).

The phone is a *thin, reliable client*. It runs no agent, no model, no tools.
All intelligence and file access stay on the machine running the engine.

## 2. Goals (v1)

- G1. Pair with a machine in under 30 seconds (QR or discovery + token).
- G2. Full chat parity with the desktop for **reading**: streaming text,
  thinking blocks, tool cards, diffs, errors, retry/compaction states.
- G3. Full chat parity for **acting**: prompt, steer (mid-turn), follow-up
  queue, abort, dequeue, model/thinking/permission-mode switching.
- G4. Approvals: accept/reject tool permission requests from the phone,
  including "Always allow (session)" via `add_session_allow_rules`.
- G5. Session management: list, open, switch, new, background-session status,
  live `sessions_update` badges.
- G6. Resilient connection: auto-reconnect, session resync after reconnect,
  correct behavior across app background/foreground and network changes.
- G7. One Flutter codebase shipping both iOS and Android.

## 3. Non-goals (v1) — do not build these

- N1. Running the engine **on** the phone (no on-device agent).
- N2. File browsing/editing UI beyond what tool cards show (defer).
- N3. Your Office / cron / bench / composio surfaces (the engine exposes them
  over RPC; the mobile app shows the chat + sessions + approvals core first —
  cron & office are M6 stretch).
- N4. Cloud relay service, hosted accounts, push notifications via APNs/FCM
  (the architecture leaves room: see §6.5).
- N5. Reusing the Expo/React Native prototype in `A-Coder-Mobile/` (see §5.3 —
  it targets an API that does not exist; its screens are reference-only).

## 4. Current state — the two host codebases

### 4.1 The engine: `a-coder-cli` (repo: `../a-coder-cli`)

Monorepo `pi-mono`-derived, packages: `agent` (core loop), `ai` (providers),
`coding-agent` (the CLI), `tui`. Published binary: `a-coder-cli`.

Key facts that matter to mobile:

- **Headless RPC mode exists and is mature**: `a-coder-cli --mode rpc`.
  NDJSON over stdin/stdout (LF-only framing). ~60 commands in, responses +
  live events out. Source of truth:
  `packages/coding-agent/src/modes/rpc/rpc-types.ts` (the full command/response
  catalog) and `packages/coding-agent/src/modes/rpc/rpc-mode.ts` (dispatcher,
  ~1500 lines).
- **Event stream** (`AgentSessionEvent`, extended by RPC-only events):
  `agent_start/agent_end`, `turn_start/turn_end`, `message_start /
  message_update / message_end` (streaming), `tool_execution_start / _update /
  _end`, `queue_update`, `subagents_update`, `tool_permission_update`,
  `compaction_start/_end`, `auto_retry_start/_end`, `session_info_changed`,
  `sessions_update`, `cron_update`, `cron_run`, `office_update`,
  `extension_ui_request` (approvals / questions / selects / notifications).
- **The desktop app** (`desktop-app/`, Tauri + React) spawns
  `a-coder-cli --mode rpc [--continue] [--provider P] [--model M]` in the
  project cwd, writes NDJSON to its stdin, reads NDJSON from stdout, and
  forwards every non-response line to the UI as a Tauri event `rpc://event`.
  Reference client: `desktop-app/src-tauri/src/rpc/client.rs` (spawn args,
  60s response timeout, id correlation) and
  `desktop-app/src/lib/rpc.ts` (~1100 lines of typed client — the single best
  reference for any mobile client implementation).
- **No network listener exists today.** The engine only speaks stdio. The
  OAuth loopback listener in `acoder-oauth-client.ts` is the only `listen()` in
  the codebase. This is the gap the bridge fills.
- **Sessions** persist as JSONL under `~/.a-coder/cli/agent/sessions/<safe-cwd>/`
  (see `session-manager.ts`). `list_sessions`, `get_messages`,
  `switch_session`, `get_tree`, `get_sessions_status` all work over RPC.
- **Auth for providers** lives in the engine (API keys, OAuth). The mobile app
  never touches provider credentials — it only talks to the bridge.

### 4.2 The desktop app (repo: `../a-coder-cli`, `desktop-app/`)

Tauri 2 (Rust) + React + Zustand + Tailwind. Spawn contract (from
`client.rs::spawn`): args `["--mode","rpc"]` + optional `--continue`,
`--provider`, `--model`; `cwd` = project dir; env `PATH` reconstructed from the
parent; stdin/stdout piped; `kill_on_drop`. Requests carry a UUID `id`;
responses are matched by `id` with a 60s timeout; every other stdout line is
emitted to the webview as event `rpc://event`.

The desktop's React stores (`session-store.ts`) show exactly how the event
stream maps to UI state (message list accumulation from
`message_start/update/end`, tool result lookup by `toolCallId`, approval
requests keyed by `id`, queue state, background processes/sub-agents). The
Flutter app replicates this state model (see
[05-app-architecture.md](05-app-architecture.md)).

### 4.3 What is missing for mobile (the gap list)

| Gap | Filled by |
|-----|-----------|
| Engine reachable over the network | `a-coder-cli serve` WebSocket bridge (M0/M1, doc 04) |
| Discovery + pairing (phone finds machine, trusts it) | mDNS announce + QR pairing + token auth (docs 02 §6, 04 §5) |
| Mobile app itself | Flutter app, docs 05–09 |
| Remote (off-LAN) access | Tailscale/VPN in v1 (zero code); cloud relay is a future phase (N4) |

## 5. Existing mobile-app folder audit (`../mobile-app`)

### 5.1 Root documents

- `api.md` — an **obsolete plan** from the previous "Void editor" era: a REST +
  WebSocket API (threads/workspace/planning, bearer tokens, Cloudflare Tunnel)
  to be embedded in an Electron app. None of those endpoints exist in
  `a-coder-cli`. Do **not** implement it. Kept only as historical context.
- `setup.md` — a generic React Native tutorial. Ignore.

### 5.2 The Expo prototype (`A-Coder-Mobile/`, one git commit, ~8.8k lines TSX)

Expo Router + NativeWind app with: theme system, onboarding, thread sidebar,
chat screen, message input, tool message cards, tool approval card, code diff
viewer, file viewer, markdown viewer, axios + AsyncStorage client wired to the
obsolete REST API (`lib/api.ts`, `lib/websocket.ts`).

What it proves (design reference only):
- The UX shape is right: thread list → chat → tool cards → approval bar →
  diff viewer → settings/connection.
- Dark-first theming with Tailwind-style tokens works on mobile.

Why it is abandoned:
- It speaks to `http://localhost:3737/api/v1/...` REST endpoints that were
  never built into the real engine; the real engine speaks NDJSON RPC over a
  spawned process.
- Rebuilding the client against the actual RPC protocol is a smaller task than
  retrofitting the prototype; and the new plan changes the stack (Flutter).

**Action for the builder**: treat `A-Coder-Mobile/app/(tabs)/chat.tsx`,
`components/chat/*`, `components/tools/*` as *visual reference* when
implementing doc 06 screens. Reuse none of its networking code.

### 5.3 Related but separate efforts

- `../a-coder-cloud-agents/` — a monetization report for cloud-hosted agent
  runs (dispatch task → container → git sync). Complementary, not required.
  The mobile plan deliberately works **without** it (local bridge first).
- `../a-coder-ide`, `../hermes-agent`, `../tandem` — unrelated projects.

## 6. Platform notes (mobile-specific constraints)

- **Backgrounding**: iOS suspends apps; sockets die. The engine keeps running
  on the desktop — reconnect-on-foreground + full resync (`get_state`,
  `get_messages`, `get_sessions_status`) is the correct model. Do not try to
  hold the socket open in the background.
- **Local network permission**: iOS requires the Bonjour services list in
  Info.plist (`NSBonjourServices` with `_a-coder._tcp`) and
  `NSLocalNetworkUsageDescription`; Android 13+ requires
  `CHANGE_NETWORK_STATE`/`ACCESS_NETWORK_STATE` and (API 33+)
  `NEARBY_WIFI_DEVICES` only if advertising. Discovery + HTTP(S)/WS to LAN
  hosts needs ATS exceptions on iOS (allow `ws://` to private IPs) — document
  exact plist/manifest keys in doc 04 §8.
- **Camera** (QR scan): `mobile_scanner` handles iOS camera permission prompt.
- **Secure storage**: token in Keychain / Android Keystore via
  `flutter_secure_storage`. Never in SharedPreferences/plain files.
- **Push** (future): engine events are real-time only while connected; v1 has
  no push (N4). Design the notification surface so a later APNs/FCM relay can
  hook in (doc 02 §7.3).