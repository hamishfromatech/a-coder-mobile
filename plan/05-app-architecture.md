# 05 — Flutter App Architecture

Framework: **Flutter ≥ 3.24**, Dart ≥ 3.5, null-safe. State: **Riverpod**
(`flutter_riverpod` + `riverpod_annotation` if codegen is enabled; plain
providers are fine without codegen). Transport: `web_socket_channel`.
This document defines the app's layering, the complete file tree, the state
model, and the runtime behaviors that make it feel native.

## 1. Layering (strict, one-directional)

```
┌─────────────────────────────────────────────────────────┐
│ UI (screens/widgets)     ConsumerWidgets only read       │
├─────────────────────────────────────────────────────────┤
│ State (Riverpod)         SessionController, events → UI  │
├─────────────────────────────────────────────────────────┤
│ Domain (models + reducer) pure Dart, unit-testable       │
├─────────────────────────────────────────────────────────┤
│ Transport (RpcClient)     WS connect, NDJSON, ids, retry │
├─────────────────────────────────────────────────────────┤
│ Platform (secure storage, discovery, scanner, perms)     │
└─────────────────────────────────────────────────────────┘
```

Rules: UI never touches `WebSocket` directly. Transport never imports Flutter
widgets (pure Dart + `dart:async`). Domain models are immutable
(`freezed` optional — plain classes with `copyThrough` helpers are acceptable;
prefer `freezed` for the ~15 protocol models, it is well-known to LLMs).

## 2. Package list (pin exact versions at creation; latest stable)

```yaml
dependencies:
  flutter_riverpod            # state
  web_socket_channel          # WS transport
  connectivity_plus           # network-change triggers
  flutter_secure_storage      # pairing tokens (Keychain/Keystore)
  shared_preferences          # non-secret settings (theme, UI prefs)
  bonsoir                     # mDNS discovery
  mobile_scanner              # QR scan
  qr_flutter                  # not needed app-side; bridge prints QR (keep for share)
  flutter_markdown_plus       # markdown rendering (or flutter_markdown, pin one)
  flutter_highlight           # code blocks in markdown
  collection, uuid, intl
dev_dependencies:
  flutter_test, mocktail, golden_toolkit (or alchemist), integration_test
```

Do not add state libs beyond Riverpod, no BLoC, no GetX, no firebase in v1.

## 3. File tree (target end state)

```
lib/
├── main.dart
├── app.dart                        // MaterialApp, theme, router, lifecycle observer
├── core/
│   ├── protocol/
│   │   ├── messages.dart           // AgentMessage + content unions (doc 03 §3)
│   │   ├── commands.dart           // typed command builders (sendX methods)
│   │   ├── events.dart             // sealed event classes parsed from JSON
│   │   ├── responses.dart          // typed responses per command
│   │   └── wire.dart               // NDJSON codec: LF split, U+2028 safe, max-line
│   ├── connection/
│   │   ├── connection_state.dart   // disconnected/connecting/auth/ready/reconnecting
│   │   ├── connection_manager.dart // state machine, backoff, ping, resync hooks
│   │   ├── rpc_client.dart         // id correlation, per-command timeouts, send queue
│   │   └── host_registry.dart      // paired hosts CRUD (secure token, rest in prefs)
│   └── util/
├── features/
│   ├── pairing/                    // screens + controller (QR, manual, discovery)
│   ├── sessions/                   // session list, tree, background sessions
│   ├── chat/                       // chat screen + controllers (the heart)
│   ├── tools/                      // tool card builders per tool name
│   ├── approvals/                  // extension_ui_request handling
│   ├── composer/                   // input, images, steer/follow-up, queue card
│   └── settings/                   // connection mgmt, appearance, about
├── design/                         // theme port (doc 09): colors, type, components
│   ├── theme.dart
│   └── components/                 // cards, chips, badges, banners, buttons
└── l10n/ (skip in v1 — English only)
test/                                // mirrors lib/ (doc 08)
integration_test/
```

## 4. State model (Riverpod)

Providers (all under `features/*/providers.dart`, colocated):

| Provider | Kind | Holds |
|---|---|---|
| `hostsProvider` | Notifier<List<PairedHost>> | paired machines; active host id |
| `connectionProvider` | Notifier<ConnState> | doc 03 §7.1 state machine |
| `sessionStateProvider` | Notifier<RpcSessionState?> | mirror of `get_state` |
| `messagesProvider` | Notifier<List<UiMessage>> | the transcript (below) |
| `toolCardsProvider` | Notifier<Map<toolCallId, ToolCardState>> | live tool executions |
| `queueProvider` | Notifier<QueueState{steering,followUp}> | from `queue_update` |
| `approvalsProvider` | Notifier<Map<requestId, UiRequest>> | pending `extension_ui_request` |
| `backgroundSessionsProvider` | Notifier<List<RuntimeSessionStatus>> | from `sessions_update` |
| `subagentsProvider` | Notifier<List<…>> | from `subagents_update` |
| `modelsProvider` | AsyncNotifier<List<Model>> | `get_available_models` (cached 5min) |
| `sessionsListProvider` | AsyncNotifier<List<RpcSessionInfo>> | `list_sessions` (pull-refresh) |
| `streamingUsageProvider` | Notifier<Usage?> | last `turn_end` usage for the header |

`UiMessage` = the render model: `Either<AgentMessage, ToolCard>` keyed by
stable ids; assistant messages merge streaming replacements by object identity
(desktop does index-based replacement — do id/role-based).

### 4.1 Event routing table (the core reducer)

One place, `session_event_router.dart`, maps every inbound JSON (doc 03 §5)
to state mutations. Implement as a pure function
`(Event, State) → State` + side-effect whitelist (toasts, sounds off in v1).
Test it with recorded fixtures (doc 08 §2). This file is the app's heart;
keep it pure and exhaustive (sealed classes, exhaustive switches).

## 5. Transport implementation notes

- `web_socket_channel` `WebSocketChannel.connect(Uri.parse(wsUrl))`; token via
  `protocols: []` + header is not supported by the package → use `?token=`
  query (bridge accepts; logs) **or** pass through `WebSocketChannel`
  `protocols` — simplest correct path: `?token=` (bridge already supports).
- One `StreamSubscription` → JSON line → `JsonEvent.parse` → router.
- Ping policy per doc 02 §7.1 (lightweight `get_state` ping; never `ping`
  frames alone — they don't exercise the engine pipeline).
- iOS ATS + Android cleartext config per doc 04 §8.

## 6. Lifecycle & reconnect rules (implement exactly)

```dart
AppLifecycleListener(onResume: () => connection.forceReconnectNow())
// connectivity change → forceReconnect()
// ready-after-reconnect sequence (in ConnectionManager):
//   get_state → get_messages → get_sessions_status → clear banner
```

- While `reconnecting`, keep rendering the last known transcript; dim it
  slightly; banner "Reconnecting… attempt 3".
- On `bridge engine_exited`: banner "Engine restarting…", keep state.
- On `ready` with `get_state.sessionFile` ≠ previous: full list rebuild.
- Streaming indicator state derives from `sessionState.isStreaming` +
  `message_update` recency (desktop parity: spinner in composer border).

## 7. Command sending surface (typed client)

Mirror `desktop-app/src/lib/rpc.ts` 1:1 — it is the reference client. Every
command gets a typed method on `RpcClient`, e.g.:

```dart
Future<RpcSessionState> getState() => _send('get_state', {}, RpcSessionState.fromJson);
Future<void> prompt(String text, {List<ImageContent>? images, String? streamingBehavior});
Future<void> steer(String text, {…}); Future<void> followUp(…);
Future<bool> removeQueued(QueueKind kind, int index);
Future<List<AgentMessage>> getMessages({Duration timeout = const Duration(seconds: 60)});
```

Send queue: enqueue while `ready`; while disconnected, composer is disabled
except "send when reconnected" opt-in (buffers one message locally — mark
clearly as unsent).

## 8. Persistence (local, non-secret)

- Paired hosts: secure storage for token + `shared_preferences` JSON for
  metadata (name, id, lastConnected).
- Appearance settings (theme mode) via `shared_preferences`.
- No transcript caching in v1 (resync covers it); revisit if perf demands.

## 9. Performance rules (chat at 60fps)

- Transcript list: `ListView.builder` + reverse; cap rendered thinking deltas
  (throttle rebuilds to 16/s via a ticker — stream deltas at full rate, UI
  coalesces; desktop pattern: render on event, throttle identical).
- Never rebuild the whole list on `message_update` — update only the
  in-flight item (`ItemKeys` by message index within the assistant turn).
- Diff rendering (edit tool): custom widget (doc 06 §4.3), lazily built.
- Image content: cache decoded bytes by hash; downscale > 2048px.
- JSON parsing off the UI isolate for lines > 256 KiB (`compute`).

## 10. Package/feature flags in-code

Single `feature_flags.dart`: `enableCron`, `enableOffice` (M6), `enableFiles`
(N2), `enablePush` (N4). Default all off except the shipped set.