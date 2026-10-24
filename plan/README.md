# A-Coder Mobile — Build Plan

These documents are the complete, self-contained build plan for the A-Coder mobile
apps (iOS + Android) that connect to a running **A-Coder engine** (the
`a-coder-cli` coding agent) on the user's desktop or home server.

They are written to be executed by an AI coding agent (or a human developer)
working **milestone by milestone**, without needing to re-derive decisions or
re-read the host codebases. Every protocol claim is grounded in the actual
source of `a-coder-cli` (paths in [09-references.md](09-references.md)).

## Read in this order

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [01-overview-and-audit.md](01-overview-and-audit.md) | Product vision, goals/non-goals, audit of what already exists (CLI engine, desktop app, the abandoned Expo prototype) and the gaps |
| 2 | [02-architecture.md](02-architecture.md) | The system architecture, the transport decision (WebSocket bridge vs in-engine server), security model, and the framework decision (Flutter) with rationale |
| 3 | [03-protocol-spec.md](03-protocol-spec.md) | **The wire contract** — framing, envelopes, every command, every event, worked examples. This is the single most important document; both sides implement from it |
| 4 | [04-bridge-spec.md](04-bridge-spec.md) | The engine-side deliverable: `a-coder-cli serve` bridge process (spawn engine ↔ WebSocket ↔ auth ↔ mDNS), with implementation pointers and acceptance criteria |
| 5 | [05-app-architecture.md](05-app-architecture.md) | Flutter app: layering, complete file tree, Riverpod state model, connection manager, reconnect/lifecycle rules, data models mapped 1:1 to the protocol |
| 6 | [06-screens-spec.md](06-screens-spec.md) | Every screen: layout, states, navigation, interactions, empty/error states |
| 7 | [07-milestones.md](07-milestones.md) | The phased build plan M0–M6. Each milestone is a self-contained work package with tasks, acceptance criteria, and test expectations — build them **in order** |
| 8 | [08-testing-and-quality.md](08-testing-and-quality.md) | Test strategy: protocol conformance suite, widget tests, integration tests, manual device matrix |
| 9 | [09-design-language.md](09-design-language.md) | Porting the desktop's design tokens (colors, typography, spacing, components) into a Flutter `ThemeData` |
| 10 | [10-references.md](10-references.md) | Exact source files in both codebases, package list with pinned versions, glossary |

## The 30-second version

- The **engine** is the `a-coder-cli` binary. It already runs headless as
  `a-coder-cli --mode rpc`: newline-delimited JSON over stdin/stdout, a rich
  command catalog (~60 commands) and a live event stream (streaming messages,
  tool executions, permission requests, queue updates).
- The **desktop app** (Tauri) spawns the engine as a child process and bridges
  its stdin/stdout to the UI. That works because the engine is local.
- A phone cannot spawn processes, so the missing piece is a small **bridge**:
  a new `a-coder-cli serve` command that spawns the engine exactly like the
  desktop does and exposes the *same* JSON protocol over an authenticated
  WebSocket, announced on the LAN via mDNS, pairable via QR code.
- The **mobile app (Flutter, iOS + Android)** speaks that same JSON protocol:
  pair once (QR or discovery), then browse sessions, watch streaming turns,
  approve tool calls, steer the agent, and manage background sessions — from
  anywhere (LAN directly; Tailscale/VPN for remote; cloud relay later).

## Ground rules for the implementing agent

1. Work milestones **in order** (see [07-milestones.md](07-milestones.md)). Do
   not start M(n+1) until M(n)'s acceptance criteria pass.
2. The protocol ([03-protocol-spec.md](03-protocol-spec.md)) is the contract.
   If the engine's real output differs from this document, **the engine wins** —
   verify against `a-coder-cli --mode rpc` and fix the doc + client.
3. Never weaken auth or auto-approve permissions. Security rules in
   [02-architecture.md §6](02-architecture.md) are hard requirements.
4. TypeScript types in the desktop app
   (`desktop-app/src/lib/rpc.ts`) are a reference implementation of the
   protocol client side; the Flutter code mirrors those shapes exactly.
5. When a package API is unclear, check the package docs (versions pinned in
   [09-references.md](09-references.md)) before guessing.