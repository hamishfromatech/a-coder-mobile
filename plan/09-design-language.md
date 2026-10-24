# 09 — Design Language (Desktop → Mobile Port)

The mobile app should feel like the desktop app in the hand. Source of truth:
`desktop-app/src/index.css` (CSS custom properties, dark default) and
`desktop-app/tailwind.config.ts`. Port the tokens 1:1 into
`lib/design/theme.dart`.

## 1. Color tokens (dark is the default; light supported)

From `index.css` `:root` (dark) — port as a `ColorScheme` extension class
`PiColors` with getters reading theme brightness (the `.light` block defines
the light overrides):

| Token (CSS) | Value (dark) | Use |
|---|---|---|
| `--pi-bg` | `rgb(10 10 12)` | app background |
| `--pi-surface` | `rgb(14 14 17)` | panels / list rows |
| `--pi-surface-raised` | `rgb(22 22 27)` | cards, composer |
| `--pi-surface-overlay` | `rgb(28 28 34)` | modals / popovers / sheets |
| `--pi-border` | `color-mix(accent 14%, transparent)` | hairlines (≈ accent @ 14% alpha) |
| `--pi-border-strong` | accent @ 26% | emphasized borders |
| `--pi-text` | `rgb(232 233 238)` | primary text |
| `--pi-text-secondary` | `rgb(168 172 184)` | secondary |
| `--pi-text-muted` | `rgb(111 115 128)` | muted |
| `--pi-text-faint` | `rgb(72 75 86)` | hints, gutters |
| `--pi-accent` | `rgb(46 127 255)` | brand blue — chips, links, live dot |
| `--pi-accent-hover` | `rgb(74 149 255)` | pressed |
| `--pi-accent-soft` | accent @ 14% | soft fills |
| `--pi-success` | `rgb(63 185 143)` | added lines, done, follow-up tag |
| `--pi-warning` | `rgb(234 179 8)` | blocked/attention |
| `--pi-error` | `rgb(240 86 86)` | removed lines, errors, deny |
| `--pi-user` | `rgb(127 209 160)` | user bubble accent |
| `--pi-tool` | `rgb(163 163 255)` | tool identity |

Light theme: swap per the `.light` block (bg `rgb(246 246 248)`, surfaces
white/near-white, borders accent @ 16/28%). Alpha-tinted rows (diff) use
`color.withValues(alpha: 0.10)` of success/error — parity with desktop's
`bg-pi-success/10`.

## 2. Typography

- Base: **system sans** (`SF Pro` / `Roboto` via `fontFamily: null` default).
- Chat body: 14sp (user-adjustable 13–17sp, doc 06 §5); line-height 1.5.
- **Monospace** (mono everywhere code/paths/args appear): `JetBrains Mono`
  (bundle via `google_fonts`, weight 400/500) — chat code blocks, tool args,
  diffs, host tokens. Sizes 11–13sp.
- Section labels (card headers): 11sp, `w600`, uppercase,
  `letterSpacing: 0.8` — matches the desktop's
  `text-4xs uppercase tracking-[0.08em]`.
- Card headers ("Task Graph" style): 12sp `w600` uppercase tracking-wide,
  `--pi-text-secondary`.

## 3. Components (build once in `design/components/`)

| Component | Spec (from desktop) |
|---|---|
| `Card` | radius 12 (`rounded-xl`), 1px `--pi-border`, surface 70% + blur feel (use `BackdropFilter` sparingly — lists use solid), smooth 150ms transitions |
| `StatusDot` | 4–8px dot: accent (live, pulse), success (done), error |
| `Chip` | pill, mono 10sp; accent=live/model, muted=idle, success, error variants |
| `Banner` | full-width strip above composer for connection/compaction/retry states |
| `IconButton` | 32×32 tap target (min 44 logical px touch target!) |
| `DiffRow` | doc 06 §4.3 — marker column 16px, gutter 40px right-aligned faint, content `whitespace-pre-wrap` |
| `ApprovalCard` | bordered, tool name mono header, args rows, 3 actions |
| `QueuedCard` | header + rows (Zap/Clock3 → accent/faint icons, right tag, hover-equivalent actions always visible on mobile — no hover states) |
| `ToolCard` | collapsible; headline row (glyph+name+summary+stats), expand → detail |

Mobile adaptations (explicitly): desktop hover reveals (`opacity-0
group-hover:opacity-100`) become always-visible but 40% opacity, 100% on
press; long-press for secondary actions; sheets instead of popovers.

## 4. Empty / error / loading states (standard widgets)

- `EmptyState(icon, title, hint, action?)` — centered, faint icon 48px,
  secondary title, muted hint. Used: no sessions, no queued, no approvals,
  discovery-none-found.
- `ErrorState(message, onRetry)` — error-tinted icon, message, retry button.
- `LoadingList` — shimmer rows matching final layout heights (never spinners
  alone in lists).
- Skeleton for transcript initial load sized from `messageCount`.

## 5. Motion (keep it minimal)

- 150–200ms ease-out on cards/expansion; nothing > 300ms.
- Streaming text: no per-character animations beyond the built-in markdown
  rebuild at 16/s throttle; typing indicator = 3-dot pulse in composer border
  (desktop parity: working spinner in border).
- Respect `MediaQuery.disableAnimations` (reduced motion).

## 6. Haptics & sound

- `HapticFeedback.selectionClick` on chip toggles, `mediumImpact` on
  send, `lightImpact` on approval allow. No sounds in v1.