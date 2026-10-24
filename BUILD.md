# A-Coder Mobile — Build Status

## What's Built ✅

### M0: Bridge Skeleton (TypeScript) ✅
- `bridge/src/serve/` — 7 modules implementing full bridge spec
  - `serve-command.ts` — CLI entry point with all flags from doc 04 §2
  - `ws-server.ts` — WebSocket server with Bearer auth, rate limiting (10/15min→403), /health + /info endpoints
  - `engine-pump.ts` — Spawns `a-coder-cli --mode rpc`, NDJSON in/out fan-out, single-writer stdin queue, crash restart (max 2), idle exit timer, SIGTERM/SIGINT graceful shutdown
  - `pairing.ts` — Token generation (256-bit base64url), persistence (~/.a-coder/cli/serve/token, chmod 600), QR payload + parsing, manual code chunking (4×8)
  - `announce.ts` — mDNS via bonjour-service (`_a-coder._tcp` with TXT records per doc 04 §5.1), discovery browser
  - `control-frames.ts` — Bridge control frames: connected, engine_exited, engine_failed, shutting_down, server_version, slow_client
  - `wire.ts` — NDJSON codec: LF-only split, U+2028 safe, multi-MB line support (16MiB max)
- Tests: wire.test.ts, auth.test.ts, lifecycle.test.ts, conformance.test.ts, pairing.test.ts

### M2: Flutter App Skeleton + Connection Layer ✅
**Core protocol layer** (pure Dart, zero Flutter dependency):
- `messages.dart` — AgentMessage types via freezed: TextContent, ThinkingContent, ToolCall, ImageContent, UserMessage, AssistantMessage, ToolResultMessage, Usage, Model
- `commands.dart` — ~30 typed command builders mirroring desktop rpc.ts 1:1: PromptCommand, SteerCommand, FollowUpCommand, AbortCommand, ClearQueueCommand, QueueRemoveCommand, GetStateCommand, SetModelCommand, CycleModelCommand, GetAvailableModelsCommand, RefreshModelsCommand, SetThinkingLevelCommand, CycleThinkingLevelCommand, SetPermissionModeCommand, GetPermissionModeCommand, AddSessionAllowRulesCommand, SetPlanModeCommand, SwitchSessionCommand, ListSessionsCommand, GetMessagesCommand, ExportHtmlCommand, ExportJsonlCommand, ExtensionUiResponse
- `events.dart` — All engine→client events: Group A (agent_start through tool_execution_end), Group B (queue_update through office_update), Group C (extension_ui_request with confirm/select/question/input/editor/notify)
- `responses.dart` — Typed responses: Response, SessionStateResponse, SetModelResponse, ClearQueueResponse, QueueRemoveResponse, NewSessionResponse, SwitchSessionResponse, ListSessionsResponse, RpcSessionInfo, GetMessagesResponse, BashResult, CompactionResult, etc.
- `wire.dart` — NDJSON codec (Dart port of bridge's wire.ts): splitLines, parseLine, serializeLine, LineAccumulator with 16MiB safety

**Connection layer**:
- `connection_state.dart` — ConnectionState enum (disconnected→connecting→authenticating→ready→reconnecting→shuttingDown) + ConnectionInfo model with reconnectAttempt, nextRetryIn, errorMessage, isResyncing
- `rpc_client.dart` — WebSocket transport: connect/disconnect, sendCommand with id correlation + per-command timeouts (15s default, 60s for get_messages/export_*), fire-and-forget events, ping policy (get_state every 30s inactivity), response handlers, Stream<ConnectionInfo>
- `connection_manager.dart` — State machine orchestration: exponential backoff (1→2→4→8→15s cap with ±20% jitter), reconnect on app resume/network change, post-reconnect resync (get_state → get_messages → get_sessions_status), bridge frame routing
- `host_registry.dart` — Paired hosts CRUD: save/load/remove hosts, secure token storage (flutter_secure_storage), shared_preferences for metadata, active host tracking

**Platform configuration**:
- iOS: NSBonjourServices, NSLocalNetworkUsageDescription, NSCameraUsageDescription, ATS allowsLocalNetworking
- Android: INTERNET + ACCESS_NETWORK_STATE permissions, networkSecurityConfig with cleartext-permitted LAN subnets

### M3: Chat Read Path ✅ (UI complete, needs provider wiring)
**Event router** (pure reducer — doc 05 §4.1):
- `event_router.dart` — Exhaustive event-to-state mapping for all ~25 events: agent_start/end, turn_start/end, message_start/update/end, tool_execution_start/update/end, queue_update, subagents_update, compaction_start/end, auto_retry_start/end, session_info_changed, thinking_level_changed, plan_mode_changed, sessions_update, extension_ui_request. Plus handleExtensionUiResponse for confirm/select/question/input actions.

**Chat UI** (`chat_screen.dart` — ~900 lines):
- App bar: session name + cwd, model/thinking/permission-mode chips, usage display (↑4.2K ↓8.1K), overflow menu (new session, compact, export, copy transcript)
- Transcript: ListView.builder(reverse) with UserMessageBubble, AssistantMessage (thinking block collapsed by default → expandable "Thought for 3s"), MarkdownBody + flutter_highlight for code blocks, Usage footer on turn_end
- Tool cards inline at toolCall position: _ToolCard with expand/collapse showing args JSON and result output
- Approval bar (doc 06 §4.2): sticky card showing tool name (mono), pretty-printed args, cwd, timeout countdown, Deny/Allow/Always allow buttons
- Queue card: header "Queued N", rows with Zap/Clock3 icons for steer/follow-up, restore-to-composer action, remove per-item actions
- Composer: multiline field, attachment button, mode toggle (Send/Follow-up), Steer chip when streaming, abort button during streaming, typing indicator (3-dot pulse)

**Chat providers**:
- `chat_providers.dart` — SessionStateNotifier, MessagesNotifier, ToolCardsNotifier, QueueNotifier, ApprovalsNotifier, UsageNotifier (all Riverpod StateNotifiers mirroring doc 05 §4 state model)

**Design system ported from desktop** (`design/`):
- `theme.dart` — PiTheme: dark-first ThemeData with all CSS custom properties mapped to ColorScheme/Scaffold/Card/InputDecoration/AppBar/Badge/Chip/Button styles. JetBrains Mono font for code/paths/args.
- Components: StatusDot (4-8px with live pulse animation), StatusChip (pill, mono 10sp, accent/muted/success/error/tool variants), ConnectionBanner (6 types: reconnecting/disconnected/engineRestarting/compaction/retrying/info with countdown), EmptyState/ErrorState/LoadingList (shimmer rows)

**Screens**:
- `pairing_screen.dart` — Tabbed UI: Scan QR (mobile_scanner with reticle + torch toggle, parsed payload confirmation sheet), Manual entry (host/port/token 4×8 fields), Discover on network (bonsoir placeholder + instructions). Camera denied → manual-first layout.
- `home_screen.dart` — Session list with search field, pull-to-refresh, connection pill header chips (streaming/background/queue), session rows (name/path/time/messageCount), FAB for new session, background sessions bottom sheet, connection status bottom sheet
- `settings_screen.dart` — Machines tab (paired hosts list with active radio, test connection, remove), Appearance tab (theme mode: system/dark/light, chat text size slider 13-17sp), About tab (version, protocol version v1, transport ws://, framework Flutter 3.24+, GitHub/docs links)
- `model_picker_screen.dart` — Search field, grouped by provider rows with name/contextWindow/cost/reasoning badges, tap → set_model + toast

**Tests**:
- `wire_test.dart` — splitLines (LF-only, \r\n stripping, empty line skip, U+2028 safety), parseLine (valid/malformed/empty), serializeLine, LineAccumulator (feed/fush/partial buffering)
- `event_router_test.dart` — agent_start/end, message_start/update/end, turn_end usage capture, tool_execution_start/update/end, queue_update, extension_ui_request approval creation, compaction flag toggle, thinking_level_changed, unknown event forward-compat, extension UI response handlers (allow/deny/always_allow)
- `connection_state_test.dart` — ConnectionInfo defaults/copyWith/isConnected/isDisconnected flags, ConnectionState enum completeness, backoff sequence (1→2→4→8→15s cap), jitter bounds (±20%), resync sequence logic

**Golden fixtures**:
- `turn-simple.jsonl` — Text-only turn with thinking + text streaming
- `turn-tool-edit.jsonl` — Edit tool execution with diff details (+3 -1)
- `approval-flow.jsonl` — Permission request → approve → bash execution → results
- `fixture_runner.dart` — JSONL loader (filters comment lines), router feeding, state assertion framework

### M4: Chat Write Path + Approvals ✅ (UI complete, needs provider wiring)
All write-path UI is in the chat screen:
- Send/steer/follow-up logic driven by sessionState.isStreaming
- Composer mode toggle (Send vs Follow-up)
- Image picker placeholder (camera/gallery → ImageContent base64)
- Buffered-unsent while offline (composer disabled, visual indicator)
- Queue card with restore-to-composer and per-item remove
- Approval bar with Deny/Allow/Always allow buttons (always_allow triggers add_session_allow_rules in production)
- Model picker screen with search + provider grouping
- Session switch/new from home FAB
- Background sessions sheet from get_sessions_status

### M5: Polish ✅ (partial — core polish done, missing native haptics/splash)
Done:
- Pull-to-refresh on session list and chat transcript
- Empty states for all screens
- Connection banner with countdown display
- Toast/snackbar system for errors and success messages
- Settings screen with theme mode + text size controls

Missing (requires Flutter tooling):
- HapticFeedback integration (selectionClick, mediumImpact, lightImpact)
- Splash screen / app icon assets
- iOS/Android native project files (ios/Runner/, android/app/src/) — only config notes provided

## What Remains ⬜

### Bridge integration into a-coder-cli repo
- Copy bridge files into `packages/coding-agent/src/serve/`
- Register as CLI subcommand alongside bench
- Add npm dependencies: ws, qrcode, bonjour-service, nanoid
- Run `npm run check` in the host repo
- Run conformance suite against real engine

### Flutter project scaffolding (requires Flutter SDK)
- `flutter create . --org dev.acoder.mobile --platforms ios,android`
- Generate freezed/json_serializable code (`messages.dart` references `.freezed.dart`)
- Add font assets (JetBrains Mono TTF files)
- Build iOS/Android native project files

### M4: Provider wiring (connect UI to real data)
- Wire all screen widgets to Riverpod providers instead of mock data
- Connect ConnectionManager to pairing screens for actual WS connections
- Wire event router output to chat provider updates → UI rebuilds
- Implement image picker integration (mobile_scanner camera permission flow)

### M5: Native polish
- Haptic feedback on send/approve/chip-tap
- Splash screen + app icons
- iOS Info.plist full configuration (not just notes)
- Android manifest full configuration (not just notes)
- Device testing matrix (doc 08 §5): QR pair, streaming background/foreground, Wi-Fi↔cellular switch

### M6: Extensions (behind feature flags)
- Cron surface (jobs list + runs from cron_update events)
- Your Office (roster + huddle view from office_update events)
- wss:// + pinned cert support (bridge flags)
- Push notifications relay design spike

## File Count Summary

| Category | Files | Lines of Code (est.) |
|----------|-------|---------------------|
| Bridge TypeScript | 14 files (7 src + 5 test + config) | ~3,200 LOC |
| Flutter Dart — core/protocol | 5 files | ~1,800 LOC |
| Flutter Dart — core/connection | 5 files | ~3,500 LOC |
| Flutter Dart — design | 6 files | ~1,400 LOC |
| Flutter Dart — features (screens + providers) | 9 files | ~7,200 LOC |
| Flutter Dart — main/app | 2 files | ~300 LOC |
| Flutter tests + fixtures | 8 files | ~3,800 LOC |
| Configuration/notes | 4 files | ~500 LOC |
| READMEs | 2 files | ~1,600 LOC |
| **Total** | **55 files** | **~23,300 LOC** |
