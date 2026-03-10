## Handoff (High-Level)

### Current Focus
- Primary: terminal architecture cleanup after the rain/render investigation stabilized the worst redraw faults.
  - detailed review + recent fix history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
  - terminal architecture plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - damage/dirty notes: `app_architecture/terminal/DAMAGE_TRACKING.md`
  - UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Active execution order now lives in `app_architecture/terminal/MODULARIZATION_PLAN.md` under `Strict Cleanup Queue (2026-03-09)`.
- Current top-of-queue focus: widget input/draw policy reduction and protocol/parser boundary typing cleanup.
- Latest correctness pitfall in that area: parser-owned startup sequences were still able to hit lock-taking input-mode helpers from inside `feedOutputBytes(...)`; kitty keyboard protocol setup now uses explicit locked key-mode paths after that bug froze `nvim`/`lazygit`/`codex-cli` during init.

### Recent Changes (High-Level)
- The high-refresh rain investigation removed most renderer-side force-full and stale invalidation escape hatches.
- Full-screen `ascii-rain` is now close to stable, so the stronger remaining work is structural rather than incident-driven.
- `TerminalSession` surface reduction is largely landed: borrowed title/cwd/scrollback/selection/input/interaction/rendering/protocol/config/runtime seams were cut back, terminal text export now lives in backend code instead of the widget, FFI/workspace/open-path callers use backend-owned metadata/export contracts instead of separate raw getter calls, split title/cwd helpers, or a dedicated child-exit getter, metadata/hyperlink/clipboard/close-confirm query logic now lives under `src/terminal/core/session_queries.zig`, generation/backlog/presentation-feedback bookkeeping under `src/terminal/core/session_publication.zig`, scrollback/text-export/scroll-offset content helpers under `src/terminal/core/session_content.zig`, selection passthrough helpers under `src/terminal/core/session_selection.zig`, key/char/text/mouse/focus/color-scheme send paths under `src/terminal/core/session_input.zig`, input-state query plus OSC 5522 paste helpers under `src/terminal/core/session_interaction.zig`, snapshot/render-cache/sync-updates damage-retirement helpers under `src/terminal/core/session_rendering.zig`, parser/control/screen-edit/alt-screen/DECRQSS protocol helpers under `src/terminal/core/session_protocol.zig`, palette/theme/column-mode/cell-size config helpers under `src/terminal/core/session_config.zig`, and PTY startup/poll/child-exit/write-lock/resize runtime helpers under `src/terminal/core/session_runtime.zig` instead of sitting inline in `terminal_session.zig`.
- Workspace/session boundary tightening is now active: app clipboard shortcuts no longer resolve sessions through workspace, the dead app-side active-session resolver was deleted, workspace tab creation now has an explicit `createTabWithSession(...)` contract, the remaining raw workspace session helpers (`sessionAt`, `activeSession`) were pushed back to internal-only helpers, terminal tab-bar sync now consumes one workspace-owned `copyTabSyncState(...)` contract, and window-close confirm routing now uses `firstConfirmCloseTab(...)` instead of app-side tab scanning.
- Runtime scheduling ownership cleanup is now effectively landed: workspace owns active-frame observation (`activeFrameState()`) and per-frame poll publication (`PollFrameResult`), runtime owns poll profile selection and sleep cadence through explicit runtime profiles, and terminal idle/backoff bookkeeping lives inside `TerminalFramePacingState` instead of generic `AppState` fields.
- Widget-input reduction also moved forward: terminal scrollbar drag state is now widget-owned instead of living in generic app state/glue, and click/drag/scroll gestures now lean on backend-owned selection/scroll helpers instead of duplicating row/word/anchor policy in `terminal_widget_input`.
- Widget/backend presentation ownership also moved forward: terminal widget draw now goes through backend-owned presentation capture/finish methods instead of assembling published-cache copy timing and feedback handoff inline in the widget.
- Clipboard/paste ownership also moved forward: system and middle-click selection paste fallback policy now lives in backend code instead of widget code, including scrollback reset for system paste, OSC 5522 attempt, bracketed paste framing, and plain-text fallback behavior.
- Scrollback-view collapse policy also moved forward: widget input no longer owns the actual “snap back to live bottom on input activity” rule; that decision now goes through backend scrollback helpers.
- Investigation residue cleanup is active: probe-grade scroll/control trace logging was removed from core hot paths, protocol trace noise now defaults to debug level, high-frequency input/scrollback send-path logs were demoted out of default-info output, raw CSI-byte tracing now defaults to debug, and duplicate stdout lifecycle logs were removed.
- Current high-risk architectural seams are:
  - `TerminalSession` is still a large multi-domain owner (PTY/parser/screens/history/render publication/UI-facing APIs).
  - terminal-originated PTY writes and the main session mutation/publication locking cleanup are now in better shape, so the next structural hotspot is the oversized `TerminalSession` surface and the borrowed app/UI query seams hanging off it.
  - redraw lifecycle ownership is significantly cleaner: published cache capture and post-draw completion are now behind backend APIs, although `view_cache`, widget wrapper code, and frame runtime still participate in the presentation pipeline.
  - scheduler/poll state is still split across app runtime helpers and `TerminalWorkspace`, but concrete workspace poll budgets now live behind the workspace contract instead of the app hook.
- protocol/parser seam is still only partially typed; the VT parser callback contract in `parser.zig`, top-level parser dispatch in `parser_hooks`, DCS/APC/OSC/CSI parser dispatch, OSC title/hyperlink/cwd/clipboard/semantic/palette/kitty-clipboard boundaries, and kitty paste-event emission/internal helper paths now run through explicit session facades/context structs (including OSC 5522 write/reply flow through an explicit `WriterFacade`). In CSI, reply emission now runs through `CsiWriter`, query/reply data through `QueryContext`, simple cursor/edit/scroll execution through `SimpleCsiContext`, `SM`/`RM` mode toggles through `ModeMutationContext`, `DECRQM` snapshot capture through `ModeQueryContext`, the remaining simple special-case control branches through `SpecialCsiContext`, and reply/control lock-dispatch orchestration through `ReplyCsiContext`; `DECSTR` now runs through an explicit reset context and `applySgr` through an explicit SGR context. `dcs_apc` also no longer bounces kitty APC payloads back through a public `TerminalSession.parseKittyGraphics(...)` wrapper. Remaining implicit seams are narrower but still exist in selected CSI policy corners, protocol entry wrappers, and some widget/backend boundaries.
- Kitty graphics has started its first real ownership split: top-level parse/control/reply policy now flows through `KittyProtocolOps`, payload transport/build through `KittyTransport`, placement mutation/query/dirty through `KittyPlacementOps`, and byte-store replacement/eviction/clear through `KittyStorageOps`. Shared kitty state/types, payload transport/build, and placement-graph mutation/scroll/placement helpers now live in dedicated `src/terminal/kitty/common.zig`, `src/terminal/kitty/transport.zig`, and `src/terminal/kitty/placement_ops.zig` modules; the remaining smell in this area is the still-large protocol/delete/storage orchestration left in `graphics.zig`.
  - widget input/draw still contain backend-policy behavior rather than being thin presentation/orchestration layers.
  - selection semantics are cleaner than before because row-content/word/range rules now live in backend model/core code, but the widget still owns substantial interaction orchestration and presentation policy.

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).
- `main` is the default branch. Feature branches are for larger isolated cuts only, and the agent owns creating, merging, and deleting them.
- Do not keep dead seams or compatibility wrappers just to avoid a hard cut when the old surface is holding the terminal back.

### Where to Look
- Primary architecture review + recent cleanup history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
- Terminal architecture plan + current hotspot list: `app_architecture/terminal/MODULARIZATION_PLAN.md`
- Terminal damage/dirty background + redraw/publication hotspot list: `app_architecture/terminal/DAMAGE_TRACKING.md`
- Current UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Doc workflow policy: `docs/WORKFLOW.md`

### Known Risk (High-Level)
- A broad refactor done in the wrong order will re-entangle correctness with redraw/scheduler changes and make regressions hard to localize.
- The main remaining risk is boundary drift: session/runtime/widget/protocol code still share responsibilities that should be isolated.
- Kitty graphics, sync/presentation ownership, and input snapshot publication remain sensitive correctness surfaces.
