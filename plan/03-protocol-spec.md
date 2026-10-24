# 03 — Wire Protocol Specification (v1)

The mobile protocol is **byte-for-byte the engine's RPC protocol**, carried
over WebSocket text frames instead of a process's stdin/stdout. This document
is the authoritative, self-contained description of that protocol, derived
from `packages/coding-agent/src/modes/rpc/rpc-types.ts` (commands/responses),
`rpc-mode.ts` (dispatch + emitted events), `packages/agent/src/types.ts`
(`AgentEvent`) and `packages/coding-agent/src/core/agent-session.ts`
(`AgentSessionEvent`). When in doubt, verify live:

```bash
a-coder-cli --mode rpc <<'EOF'
{"type":"get_state"}
{"type":"get_messages"}
EOF
```

## 1. Framing

- Each message (command, response, or event) is **one JSON object serialized
  on one line**, terminated by `\n` (LF only). Over WebSocket, one line =
  one text frame (the bridge maps 1:1; see doc 04 §4).
- Strict JSONL: split on `\n` **only**. Payload strings may contain U+2028/
  U+2029 — they are legal inside JSON strings and must NOT split records.
  (Rationale: the engine's `jsonl.ts` deliberately avoids readline for this.)
- Trailing `\r` before `\n` is stripped (engine does this too).
- Max line size: engine output is unbounded in principle (a tool result can be
  large). Client parser must handle multi-MB lines without dropping the
  connection. Do not set a low WS max-payload (use ≥ 16 MiB).

## 2. Envelopes

Three envelope shapes appear on the wire. Discriminate on the `type` field:

```jsonc
// (1) Command — client → engine. Optional correlation id.
{"type": "prompt", "message": "fix the failing test", "id": "c1f0…"}

// (2) Response — engine → client, exactly one per command id.
{"id": "c1f0…", "type": "response", "command": "prompt", "success": true}
{"id": "x", "type": "response", "command": "get_state", "success": true, "data": {…}}
{"id": "x", "type": "response", "command": "set_model", "success": false, "error": "Unknown model"}

// (3) Event — engine → client, no id.
{"type": "message_start", "message": {…}}
```

Rules:
- Commands may omit `id`, but clients MUST always send one (UUID v4).
- Responses for unknown/timeout ids are logged and dropped.
- Events never carry `id`. `extension_ui_request` carries its own `id`
  (different namespace) used for `extension_ui_response`.
- Unknown event types: ignore (forward-compat). Unknown command types:
  engine answers `{"success": false, "error": "Unknown command: …"}`.

## 3. Message model (`AgentMessage`)

Everything the chat renders is built from these three roles (from
`packages/ai/src/types.ts`):

```ts
UserMessage {
  role: "user"; content: (TextContent | ImageContent)[]; timestamp: number;
}
AssistantMessage {
  role: "assistant";
  content: (TextContent | ThinkingContent | ToolCall)[];
  api, provider, model, responseModel?, usage: Usage, stopReason,
  errorMessage?, retryAfterMs?, timestamp
}
ToolResultMessage {
  role: "toolResult"; toolCallId: string; toolName: string;
  content: (TextContent | ImageContent)[]; details?: any; isError: boolean;
  timestamp: number;
}
TextContent     { type: "text"; text: string }
ThinkingContent { type: "thinking"; thinking: string }
ToolCall        { type: "toolCall"; id: string; name: string; arguments: object }
ImageContent    { type: "image"; data: string /* base64, no data: prefix */; mimeType: string }
Usage           { input: number; output: number; cacheRead: number; cacheWrite: number; cost.total? }
```

Streaming note: during a turn, `message_update` carries the **full, rebuilt**
`AssistantMessage` each time (not a delta). Clients replace the in-flight
message wholesale — this is exactly what the desktop does
(`desktop-app/src/lib/rpc.ts` `handleEvent`).

## 4. Command catalog

Grouped; exact payloads from `rpc-types.ts`. `sessionPath?` on prompting
commands targets a **background session** by file path (from
`get_sessions_status`); omit = active session.

### 4.1 Prompting & queue
| Command | Payload | Response data | Notes |
|---|---|---|---|
| `prompt` | `{message, images?, streamingBehavior?: "steer"\|"followUp", sessionPath?}` | — (events follow) | while streaming behaves per mode; idle → starts a turn |
| `steer` | `{message, images?, sessionPath?}` | — | queue into steering; delivered next LLM call of current turn |
| `follow_up` | `{message, images?, sessionPath?}` | — | queued; runs only when the agent would stop |
| `abort` | `{sessionPath?}` | — | aborts current run |
| `clear_queue` | `{sessionPath?}` | `{steering: string[], followUp: string[]}` | dequeue-all (TUI "restore to editor") |
| `queue_remove` | `{kind: "steering"\|"followUp", index, sessionPath?}` | `{removed: boolean}` | remove one queued item (order per `queue_update`) |
| `stop_workflow_run` | `{runId}` | `{stopped: boolean}` | stop a running script workflow |
| `new_session` | `{parentSession?, cwd?}` | `{cancelled}` | fresh session |
| `clear_conversation` | — | — | clears transcript in place |

### 4.2 State & models
| Command | Response data |
|---|---|
| `get_state` | `RpcSessionState` (below) — send on connect + after reconnect |
| `set_model` | `{Model}` — `{id, name, provider, contextWindow, maxTokens, input[], reasoning, cost{...}}` |
| `cycle_model` | `{model, thinkingLevel, isScoped}` \| `null` |
| `get_available_models` | `{models: Model[]}` |
| `refresh_models` | — (forces provider re-fetch) |
| `set_thinking_level` / `cycle_thinking_level` | `{level}` \| `null` — `"off"|"minimal"|"low"|"medium"|"high"` |
| `set_permission_mode` / `get_permission_mode` | `{mode}` — `"default"\|"plan"\|"auto"` (names per engine; render verbatim) |
| `add_session_allow_rules` | — `{rules: string[]}` e.g. `["bash(npm test)"]` (desktop "Always allow") |
| `set_plan_mode` / `get_plan_mode` | — |
| `set_steering_mode` / `set_follow_up_mode` | `"all" \| "one-at-a-time"` |

### 4.3 Sessions & history
| Command | Response data |
|---|---|
| `get_state` | `RpcSessionState {model?, thinkingLevel, permissionMode, planMode, isStreaming, isCompacting, steeringMode, followUpMode, cwd?, sessionFile?, sessionId, sessionName?, autoCompactionEnabled, compactionAutoContinue, messageCount, pendingMessageCount}` |
| `get_messages` | `{messages: AgentMessage[]}` — full transcript (slow for big sessions; 60s timeout) |
| `get_entries` / `get_tree` | session JSONL entries / tree (`{entries|tree, leafId}`) |
| `list_sessions` | `{sessions: RpcSessionInfo[]}` — `{path, id, cwd, name?, parentSessionPath?, created, modified, messageCount, firstMessage}` (dates ISO) |
| `switch_session` | `{cancelled, reattached?, snapshot?: {running, needsInput, pendingMessageCount}}` — **after switching, re-run get_messages + get_state** |
| `new_session`, `clone`, `fork` | `{cancelled…}` / `{text}` |
| `set_session_name`, `set_entry_label` | — |
| `get_session_stats` | token/cost stats |
| `get_sessions_status` | `{sessions: RuntimeSessionStatus[]}` — background sessions (running/needsInput) |
| `abort_session` | `{found}` — abort a background session |
| `rewind` | — file-history rewind (v1: hide in UI) |

### 4.4 Bash, compaction, retry (power-user actions)
| Command | Payload / Response |
|---|---|
| `bash` | `{command, excludeFromContext?}` → `BashResult {stdout, stderr, exitCode, cancelled?}` |
| `abort_bash` | — |
| `compact` | `{customInstructions?}` → `CompactionResult` |
| `set_auto_compaction`, `set_compaction_auto_continue`, `set_auto_retry`, `abort_retry` | toggles |
| `export_html` / `export_jsonl` / `import_jsonl` | file paths (engine-side); mobile shows returned path |

### 4.5 Extension UI (approvals/questions) — stdin
Responses to `extension_ui_request` (see §5.6), shape
`{type: "extension_ui_response", id, …}`:
- `confirm` → `{confirmed: boolean}`
- `select` → `{value: string}`
- `question` → `{answers: Record<header, answer>}`
- `input`/`editor` → `{value: string}`
- cancel/timeout → `{cancelled: true}`

## 5. Event catalog (engine → client)

Discriminate on `type`. Group A are `AgentSessionEvent`s; group B are
RPC-only; group C are extension UI requests.

### Group A — agent lifecycle & streaming
| Event | Payload | UI |
|---|---|---|
| `agent_start` | — | turn begins; composer shows stop |
| `turn_start` | — | turn marker |
| `message_start` | `{message}` (role user/assistant/toolResult) | append message row |
| `message_update` | `{message, assistantMessageEvent}` | replace in-flight assistant message (full rebuild). `assistantMessageEvent.type` ∈ `text_start/text_delta/text_end/thinking_start/thinking_delta/thinking_end/toolcall_start/toolcall_delta/toolcall_end/done/error` — use for typing indicator & per-block animation |
| `message_end` | `{message}` | finalize row |
| `turn_end` | `{message, toolResults, usage?}` | update usage chips |
| `agent_end` | `{messages, willRetry}` | turn done; if `willRetry`, show "retrying" |
| `tool_execution_start` | `{toolCallId, toolName, args}` | tool card (running) |
| `tool_execution_update` | `{toolCallId, toolName, args, partialResult}` | live output (bash tail, etc.) |
| `tool_execution_end` | `{toolCallId, toolName, result, isError}` | finalize card; for `edit` render `result.details.diff` (doc 06 §4) |

### Group B — session/runtime state
| Event | Payload | UI |
|---|---|---|
| `queue_update` | `{steering: string[], followUp: string[]}` | queued card + badge |
| `subagents_update` | `{agents: InProcessSubAgentRecord[]}` | agents strip |
| `tool_permission_update` | `{toolCallId, waiting}` | approval emphasis |
| `compaction_start/_end` | `{reason, result?, aborted, willRetry, errorMessage?}` | compacting banner |
| `auto_retry_start/_end` | `{attempt, maxAttempts, delayMs, errorMessage}` / `{success, attempt, finalError?}` | retry banner |
| `session_info_changed` | `{name}` | title bar |
| `thinking_level_changed` / `plan_mode_changed` | `{level}` / `{enabled}` | header chips |
| `entry_appended` | `{entry}` | (ignore in v1 UI) |
| `sessions_update` | `{sessions: RuntimeSessionStatus[]}` | background sessions badge |
| `cron_update` / `cron_run` | `{jobs}` / `{event, run}` | (M6) |
| `office_update` / `office_huddle` / `office_activity` | snapshots | (M6) |
| `session_start` | `{reason, …}` (SessionStartEvent) | (ignore) |

### Group C — `extension_ui_request` (engine needs an answer)
Methods seen by clients (full shapes in rpc-types §Extension UI Events):
`select`, `question` (structured multi-choice w/ `options[].label/description`,
`multiSelect`), `confirm` (**`kind?: "permission"` + `toolName` + optional
`workflow {name, phases}`** — the tool-approval path; render the approval
card), `input`, `editor`, `notify` (`notifyType: info|warning|error` → toast/
banner), `setStatus`, `setWidget`, `setTitle`, `set_editor_text`.
Answer with the matching `extension_ui_response` (doc §4.5). Requests can
carry `timeout`; if the client stays silent the engine resolves by its default.

**Approval card contract (must-have):** on
`{method:"confirm", kind:"permission", toolName}` render tool name, pretty
args, cwd, and Allow / Allow-always / Deny. Allow-always =
`add_session_allow_rules {rules: [toolCallRule]}` then `confirmed:true`.
Desktop reference: `desktop-app/src/components/ToolApprovalBar.tsx`.

## 6. Worked example — one full turn

```
→ {"id":"a1","type":"prompt","message":"rename foo() to bar() in src/x.ts"}
← {"id":"a1","type":"response","command":"prompt","success":true}
← {"type":"agent_start"}
← {"type":"turn_start"}
← {"type":"message_start","message":{"role":"assistant","content":[],…}}
← {"type":"message_update","message":{…content:[{type:"thinking",…}]…}}   (×N)
← {"type":"message_update","message":{…content:[{type:"text",…}]…}}      (×N)
← {"type":"message_end","message":{…content:[thinking, text, toolCall:{id:"t9",name:"edit",arguments:{…}}]…}}
← {"type":"tool_execution_start","toolCallId":"t9","toolName":"edit","args":{…}}
← {"type":"tool_execution_end","toolCallId":"t9","toolName":"edit","result":{"content":[…],"details":{"diff":"…","patch":"…"},"isError":false}}
← {"type":"message_start","message":{"role":"toolResult","toolCallId":"t9","toolName":"edit",…}}   (result enters transcript)
← {"type":"message_end","message":{…toolResult…}}
← {"type":"turn_start"} … (model continues; loop repeats)
← {"type":"turn_end","message":{…},"toolResults":[…],"usage":{…}}
← {"type":"agent_end","messages":[…],"willRetry":false}
```

Permission-gated tool: `tool_execution_start` may NOT fire; instead:
```
← {"type":"extension_ui_request","id":"u1","method":"confirm","kind":"permission","toolName":"edit","title":"Allow edit?","message":"…"}
→ {"type":"extension_ui_response","id":"u1","confirmed":true}
← {"type":"tool_execution_start",…}   (only now)
```

## 7. Errors & edge cases

- `success:false` responses carry human `error`. Map known ones (unknown
  session, unknown command) to toasts; always log raw.
- Engine process death → bridge emits a control frame
  `{"type":"bridge","event":"engine_exited","code":N}` (bridge-owned envelope;
  the ONLY non-engine envelope) then closes; client shows a reconnect banner.
- `get_messages` on a huge session can take seconds; render from
  `get_state.messageCount` a skeleton, never block the composer.
- Images in prompts: `ImageContent{data: base64, mimeType}`; the phone sends
  camera/gallery picks (≤8MB each, JPEG/PNG) — same shape the desktop sends.
- Timestamps are Unix ms (`Date.now()`). `RpcSessionInfo` dates are ISO
  strings — normalize in the client model layer.
- Clock skew: never order by timestamps; order = arrival + `messageCount`.

## 8. Conformance checklist (both sides must pass — see doc 08)

1. LF-only framing; handles U+2028/2029 inside strings; `\r\n` tolerated.
2. id correlation incl. late/duplicate/unknown ids.
3. Every command in §4 round-trips against a live engine (scripted suite).
4. The §6 turn example replays identically over the bridge.
5. `extension_ui_request` confirm/question/select/input round-trips.
6. Multi-MB line (`bash` with huge stdout) parses without frame loss.
7. Bridge control frames (`bridge`) parse and don't confuse the event router.