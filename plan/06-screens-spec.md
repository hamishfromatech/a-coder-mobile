# 06 — Screen Specification

Conventions: every screen lists **Layout → States → Interactions**.
Global chrome: top app bar shows host name (tap → host sheet), session name +
cwd chip, connection pill (`ready`/`reconnecting N`/`offline`), usage chip
(tokens of last turn). Design tokens in doc 09. Navigation: go_router-style
declarative routes.

Route map:
```
/                     → gate: no hosts → Pairing; else → Home
/pair                 → Pairing (scan | manual | discover tabs)
/home                 → session list + status header
/chat/:hostId/:sessionPath? → chat
/model                → model picker (modal)
/settings             → hosts, appearance, about
/background           → background sessions (from home header chip)
```

## 1. Pairing (`/pair`) — first-run and "add machine"

**Layout.** Segmented control: `Scan QR` / `Manual` / `On this network`.
- Scan: full-bleed camera (mobile_scanner), reticle, torch toggle. On detect →
  parse QR payload (doc 04 §5.2) → confirm sheet ("Connect to Hamish's
  MacBook? 192.168.1.20:8787") → Connect.
- Manual: host, port, token (4×8 char fields, paste-all support).
- Discover: live list from bonsoir `_a-coder._tcp` (name, host, port, resolved
  IP); tap → token entry sheet (token still required — discovery never
  bypasses auth).
**States**: idle / scanning / connecting (state machine visible: connecting →
authenticating → syncing → ready) / failure (timeout, 401 wrong token, rate
limited) with retry.
**Interactions**: Connect runs first resync (get_state → get_messages); on
success → save host → navigate `/home`. Failure → inline error + "Check that
serve is running on the desktop (`a-coder-cli serve`)".
**Empty/error**: camera denied → manual-first layout with explanatory card.

## 2. Home — sessions & status (`/home`)

**Layout**:
- Header: machine name + connection pill; chips row: `● streaming` (if
  isStreaming), `N background` (tap → background sheet), `queue N`.
- Search field (filters by name/first message).
- Session list (pull-to-refresh = `list_sessions`): rows show name (or first
  message), relative time, message count, small token-usage text if present,
  `parentSessionPath` sub-badge for child sessions.
- FAB: new session (`new_session` → navigate to chat).
**States**: loading shimmer; empty ("No sessions yet — start from the chat");
error (retry).
**Interactions**: tap → `/chat` (issues `switch_session` then
`get_messages`+`get_state`); long-press → rename (`set_session_name`), export
(export_html/jsonl — show returned engine path as toast).
**Background sessions sheet**: rows from `get_sessions_status` /
`sessions_update` — cwd, status (running/needsInput), pending count; actions:
open (switch_session), abort (`abort_session`).

## 3. Chat (`/chat`) — the core screen

**Layout** (top to bottom):
1. App bar: back, session name + cwd, model chip (tap → model picker),
   thinking chip, permission-mode chip (tap → mode sheet), overflow menu
   (new session, compact, export, rewind, copy transcript).
2. Transcript `ListView.builder` (reverse) of `UiMessage`s:
   - **User bubble**: right-aligned, text + image thumbnails.
   - **Assistant**: markdown (flutter_markdown_plus + flutter_highlight for
     fenced code); thinking blocks collapsed by default ("Thought for 12s" →
     expandable, muted italic); usage footer on `turn_end` (in/out/cache/tokens,
     cost if present, stopReason icon).
   - **Tool cards** (§4) inline at the toolCall position.
   - **Errors**: red-bordered card with `errorMessage`, retry hint when
     `willRetry`/`auto_retry_*`.
3. Sticky approval bar (when `approvalsProvider` non-empty): doc §4.2.
4. Queued card (when `queueProvider` non-empty) — same anatomy as desktop:
   header "Queued N", rows with steer/follow-up tag, restore (→ composer),
   remove (queue_remove).
5. Composer: multiline field, attachment (image picker/camera →
   ImageContent base64), mode chip showing destination: when `isStreaming`
   the send button becomes **Steer** (accent); a mode toggle switches to
   **Follow-up** (queues instead). Disabled while disconnected (except
   buffered-unsent mode). Send = `prompt` / `steer` / `follow_up`.

**States**: fresh (loading transcript w/ skeleton by `messageCount`),
empty (hero: "Session X — send the first task"), streaming, error
(assistant `errorMessage` card + retry hint).

**Interactions**:
- Pull-down: refresh transcript (`get_messages`).
- Message long-press: copy text / copy block.
- Tap tool card → detail sheet (full args JSON, full output, for edit the
  full diff, for read the file snippet; mono font, select-all enabled).
- Banner row (compaction/retry) per event map (doc 05 §4.1).

### 4.2 Approval bar (must be flawless)

`extension_ui_request` `confirm`+`kind:permission`:
- Card: tool icon + `toolName` monospaced, args pretty-printed (key: value
  rows, JSON for nested), cwd, timeout countdown if provided.
- Buttons: **Deny** (subtle) / **Allow** (primary) / **Always allow** (for
  `bash`/`edit`/`write`-style: sends `add_session_allow_rules {rules:[…]}` with
  the same rule string the desktop derives — reference
  `desktop-app/src/components/ToolApprovalBar.tsx` for exact rule derivation).
- Only one pending permission at a time (engine serializes); `question`
  requests render as option list cards (label + description rows, multiSelect
  if flagged), `select`/`input` render native pickers/dialogs.
- If a request has `timeout`, show the countdown; on expiry, the engine
  resolves it server-side — the client clears pending state on
  `tool_permission_update {waiting:false}` or the matching response.

### 4.3 Tool card renderers (map `toolName` → card)

| Tool | Card content |
|---|---|
| `bash` | command (mono), live stdout tail (tool_execution_update), exit pill (`exit 0 · 1.2s`) |
| `read` | path + "N lines" headline; expandable preview |
| `edit` | `+A −R` chips (from `details.diff`) + **DiffView**: rows with marker gutter (+/−/space), right-aligned line number, green/red tinted rows, `···` for collapsed regions — port the desktop's `EditDiff.tsx` (exact parser spec: `^[ +−-](\d*) ?(.*)$` after pad-strip; see desktop `desktop-app/src/components/tool-renderers/EditDiff.tsx`) |
| `write` | path + "N lines" |
| `grep`/`find`/`ls` | query + counts, expandable results |
| `task_*` | task graph mini-card (subject + status dot) |
| others / MCP | name + args summary + generic output block |

Unknown tools and extension tools: generic card (name, args JSON collapsed,
output monospace). Never crash on unknown shapes — fail soft to a JSON card.

## 4. Model picker (`/model`)

Search field; grouped by provider (from `get_available_models`; group key
`model.provider`); rows: name, context window chip, cost chip (from
`Model.cost`), reasoning badge; current highlighted; tap → `set_model` → pop
with toast. Pull-to-refresh = `refresh_models` then re-fetch. Local provider
rows (ollama, lm-studio, llama-cpp) show live badge if `provider` matches.

## 5. Settings (`/settings`)

- **Machines**: list of paired hosts (name, host:port, last connected), active
  radio; add (→ /pairing); swipe remove (confirm; revoke local only).
- Active host details: host:port, token field (masked, reveal w/ biometric via
  local_auth optional), last connected, "Test connection".
- Appearance: theme mode (system/light/dark), text size (chat only: 13–17sp).
- Danger: "Forget this device" (wipes token).
- About: version, protocol version (doc 03), links.

## 6. Global components

- **ConnectionBanner** (top of every screen when not ready): states from the
  connection machine with attempt counter and next-retry countdown.
- **StatusPill / chips**: reuse desktop semantics (accent=live, muted=idle,
  error=red, success=green).
- **Toast system**: `notify` events (`notifyType`) → themed toasts; also used
  for client errors.
- **Empty/error widgets**: standardized (doc 09 §4).