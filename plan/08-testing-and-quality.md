# 08 — Testing & Quality

## 1. Principles

1. **The protocol is a contract — test it as one.** A scripted conformance
   suite drives a real `serve` + engine and asserts every doc-03 guarantee.
   It runs in the host repo's vitest (bridge side) and in Flutter
   (`dart test`-style unit tests) against recorded fixtures.
2. **Pure-core testing.** The event router (doc 05 §4.1), the wire codec, the
   connection state machine, and the tool-card parsers are pure functions —
   they get exhaustive unit tests before any widget work (M3 depends on them).
3. **Golden fixtures over mocks where it matters.** Record real engine output
   (never hand-write protocol fixtures except failure injections).

## 2. Recorded fixtures (build in M3)

`mobile-app/app/test/fixtures/` (JSONL, one per scenario):

| Fixture | Scenario |
|---|---|
| `turn-simple.jsonl` | text-only turn (doc 03 §6 minus tool) |
| `turn-tool-edit.jsonl` | edit tool incl. `details.diff` with all row kinds (+/−/ctx/skip/padded numbers) |
| `turn-tool-bash.jsonl` | bash with `tool_execution_update` partials + non-zero exit |
| `approval-flow.jsonl` | `extension_ui_request` confirm(permission) → response → execution |
| `question-flow.jsonl` | structured question, multiSelect |
| `reconnect.jsonl` | mid-turn disconnect → `bridge engine_exited` → restart → `sessions_update` |
| `big-line.jsonl` | 4 MiB single-line tool result (U+2028 inside) |
| `errors.jsonl` | success:false responses, unknown events, malformed line |

Fixture runner: parse fixture → feed the router → assert final UI state
(snapshot of providers) and intermediate transitions. The `reconnect`
fixture additionally drives the ConnectionManager with a fake clock.

## 3. Bridge test matrix (vitest, `packages/coding-agent/test/serve/`)

- `wire.test.ts`: framing (§8 checks 1, 6), control frames, fan-out order.
- `auth.test.ts`: token accept/deny, timing-safe, rate limit lockout, `?token=`
  warning, `--no-auth` guard.
- `lifecycle.test.ts`: spawn on first client, idle exit, crash-restart ≤2,
  clean shutdown ordering (SIGTERM→grace→SIGKILL).
- `conformance.test.ts`: catalog round-trip (§8 check 3) — iterate every
  command type from `rpc-types.ts`, assert a `response` arrives (success or
  documented failure) and, where the engine emits follow-up events, that they
  parse as known events.
- Use a **fake engine** (a Node script emitting canned JSONL, honoring a
  `--crash-after` env) for 1/3/4; one smoke test uses the real engine binary
  if present on CI (skip otherwise).

## 4. Flutter tests

- Unit: wire codec (U+2028/multi-MB), rpc id matching (late/unknown/dup),
  backoff sequence + jitter bounds, secure storage round-trip (mocked).
- Router: every fixture in §2 → final-state assertions.
- Widget: golden tests (dark+light) for: user/assistant bubbles, thinking
  block (collapsed/expanded), each tool card, approval card (all buttons),
  queue card, connection banner (all states), model picker rows.
- Integration (`integration_test/`): needs a running bridge — gate behind
  `ACODER_E2E_HOST` env like the repo's e2e convention; covers pair → chat →
  approve (doc 07 M4).
- Performance: a 500-message fixture list scrolled in profile mode; assert
  no jank > 16ms frame budget on the profile run (manual, matrix below).

## 5. Manual device matrix (M5 gate)

| Check | iPhone (iOS 17+) | Android (13+) |
|---|---|---|
| QR pair | ✔ | ✔ |
| Discovery list | ✔ (local network prompt) | ✔ |
| Streaming 10-min turn, screen off/on | resync ok | resync ok |
| Wi-Fi ↔ cellular switch | reconnect | reconnect |
| Kill/restore bridge | banner → resync | banner → resync |
| Approval card w/ 20s timeout | renders + answers | renders + answers |
| 2MB bash output tool card | no frame loss | no frame loss |
| Background 5min → foreground | resync < 2s | resync < 2s |
| Token persisted (app restart, no re-pair) | Keychain | Keystore |
| Rotate token → old client 401 | ✔ | ✔ |

## 6. Quality gates per PR

- Bridge: `npm run check` (repo-wide) + `./test.sh` green (doc 04 §9.7).
- Flutter: `flutter analyze` zero infos, `flutter test` green, goldens
  reviewed, `flutter analyze --no-pub --fatal-infos` in CI.
- No new dependency without: exact version pin, popularity/maintenance check
  (pub.dev score ≥ 70 / actively maintained), license (MIT/BSD/Apache only),
  and a one-paragraph justification in the PR.
- Security self-review checklist on any PR touching auth/storage/transport:
  token never logged; timing-safe compare; storage encrypted; no `print` of
  payloads; rate limits intact.