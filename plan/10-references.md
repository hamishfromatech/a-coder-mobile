# 10 — References, Packages & Glossary

## 1. Source files in the host repos (ground truth)

### Engine protocol (repo `../a-coder-cli`)
| File | Why it matters |
|---|---|
| `packages/coding-agent/src/modes/rpc/rpc-types.ts` | **The command/response/event catalog** — the protocol's source of truth |
| `packages/coding-agent/src/modes/rpc/rpc-mode.ts` | Dispatcher; how commands run; extension UI plumbing; emitted RPC-only events |
| `packages/coding-agent/src/modes/rpc/jsonl.ts` | NDJSON framing rules (LF-only, U+2028 rationale) |
| `packages/agent/src/types.ts` | `AgentEvent` union (message/tool/turn lifecycle) |
| `packages/agent/src/agent.ts` | Agent queues (steer/followUp), `removeSteeringAt/removeFollowUpAt` |
| `packages/coding-agent/src/core/agent-session.ts` | `AgentSessionEvent`, queue semantics, `removeQueuedMessage`, session state |
| `packages/ai/src/types.ts` | `AgentMessage` + content unions (`TextContent`, `ThinkingContent`, `ToolCall`, `ImageContent`), `Model`, `Usage` |
| `desktop-app/src-tauri/src/rpc/client.rs` | How the desktop spawns the engine (flags, PATH, 60s timeout, id correlation) |
| `desktop-app/src/lib/rpc.ts` | **Typed client reference implementation** (~60 commands + event handling) — mirror in Dart |
| `desktop-app/src/stores/session-store.ts` | Event → UI-state mapping reference (messages, queue, approvals, background) |
| `desktop-app/src/components/ToolApprovalBar.tsx` | Approval UX + "Always allow" rule derivation |
| `desktop-app/src/components/tool-renderers/EditDiff.tsx` | Diff row parser for `edit` results (`details.diff`) |
| `packages/coding-agent/src/core/tools/edit.ts` | Where `details.diff`/`details.patch` come from |
| `packages/coding-agent/src/core/session-manager.ts` | Session storage layout (`~/.a-coder/cli/agent/sessions/<safe-cwd>/`) |
| `packages/coding-agent/src/cli/bench-command.ts` + `src/main.ts` | Where to register the new `serve` subcommand |
| `packages/coding-agent/AGENTS.md` (repo root) | Repo coding rules the bridge PRs must follow |

### Mobile reference (repo `../mobile-app`)
| Path | Use |
|---|---|
| `A-Coder-Mobile/app/(tabs)/chat.tsx` | visual reference for chat layout |
| `A-Coder-Mobile/components/chat/*` | thread list, message input, approval card visuals |
| `A-Coder-Mobile/components/tools/*` | tool card + diff viewer visuals |
| `A-Coder-Mobile/components/onboarding/OnboardingScreen.tsx` | pairing flow visual reference |
| `api.md` (root) | obsolete Void-era REST plan — **do not implement**; historical only |

## 2. Package decisions (Flutter side)

Pinned at app creation (M2); the LLM should use latest stable and record
exact versions in `app/pubspec.lock` + update the table below. All chosen for
maintenance + popularity (pub.dev points ≥ 75 unless noted):

| Concern | Package | Notes |
|---|---|---|
| State | `flutter_riverpod` (+ `riverpod_annotation`/codegen optional) | doc 05 §4 |
| WebSocket | `web_socket_channel` | official |
| Secure storage | `flutter_secure_storage` | Keychain/Keystore |
| Preferences | `shared_preferences` | non-secret only |
| Connectivity | `connectivity_plus` | reconnect triggers |
| mDNS | `bonsoir` | doc: discover + resolve; Bonjour/NSD |
| QR scan | `mobile_scanner` | CameraX/AVFoundation based |
| Markdown | `flutter_markdown_plus` or `flutter_markdown` | pick one, pin |
| Code highlight | `flutter_highlight` | pairs with markdown |
| Models | `freezed`, `json_serializable` | protocol models |
| Tests | `mocktail`, `alchemist` (goldens) | doc 08 |

Bridge side (engine repo): `ws`, `qrcode`, `bonjour-service`, `nanoid` —
pure JS, no lifecycle scripts (repo install policy:
`npm install --ignore-scripts`).

## 3. Engine CLI surface used by the project

```bash
a-coder-cli --mode rpc [--continue] [--provider <id>] [--model <id>]   # engine (stdio NDJSON)
a-coder-cli serve [--cwd D] [--port N] [--bind A] [--provider] [--model] [--continue]
                   [--token T] [--token-file P] [--max-clients N] [--idle-exit M]
                   [--no-auth (127.0.0.1 only)] [--no-announce] [--rotate]
```

Sessions on disk: `~/.a-coder/cli/agent/sessions/<safe-cwd>/*.jsonl`.
Bridge state: `~/.a-coder/cli/serve/{token,clients.json}`.

## 4. Glossary

| Term | Meaning |
|---|---|
| **Engine** | `a-coder-cli --mode rpc` process; owns sessions, tools, LLM calls |
| **Bridge** | `a-coder-cli serve`; spawns engine, WS+auth+mDNS in front of it |
| **Host** (app) | a paired machine running a bridge (phone may store several) |
| **Session** | one conversation JSONL; active or background (`sessionPath`) |
| **Steering** | message queued into the *current* turn; delivered before the next LLM call |
| **Follow-up** | queued message delivered only when the agent would otherwise stop |
| **queue_update** | event mirroring both queues' string arrays (order = indices used by `queue_remove`) |
| **extension_ui_request** | engine → client request needing an answer (approvals are `confirm` + `kind:"permission"`) |
| **turn** | one assistant response cycle (may include many tool calls) |
| **NDJSON** | newline-delimited JSON; LF-only framing (doc 03 §1) |
| **Resync** | post-reconnect sequence: `get_state` → `get_messages` → `get_sessions_status` |
| **Paired host** | {host, port, token, name, id} stored on the phone |

## 5. Open questions / decisions log

| # | Question | Decision (date) |
|---|---|---|
| 1 | Bridge vs in-engine WS server | Bridge (`serve` subcommand) — doc 02 §2 (2026-09-24) |
| 2 | Flutter vs native ×2 | Flutter — doc 02 §3 (2026-09-24) |
| 3 | Reuse Expo prototype? | No — visual reference only — doc 01 §5.2 (2026-09-24) |
| 4 | Remote access in v1 | LAN + Tailscale/VPN; relay deferred — doc 01 N4 (2026-09-24) |
| 5 | Auth scheme | Per-machine bearer token, mDNS+QR pairing — doc 04 §5 (2026-09-24) |
| 6 | Cross-project switching | Out of v1 (engine is per-cwd) — doc 04 §7 (2026-09-24) |