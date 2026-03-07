# Zide Performance Review (Dock/Layout)

Date: 2026-01-19 (status updated 2026-01-28)
Scope: UI layout/dock structure and redraw behavior, with a focus on responsiveness and CPU usage.

## Dock/Layout Structure (Current)
- Layout is a fixed vertical stack plus side nav:
  - Options bar (top)
  - Tab bar (below options)
  - Editor pane (center)
  - Terminal pane (bottom, optional; resizable by dragging separator)
  - Status bar (bottom overlay)
  - Side nav (left)
- Terminal is a bottom dock that reduces editor height; there is no split-pane manager beyond this.
- Draw order: options bar → tab bar → editor → terminal (if visible) → side nav → status bar.
- Terminal renders into a cached texture and re-renders only dirty rows (background + glyphs).

## Current Redraw Behavior
- Global `needs_redraw` drives full-frame redraw.
- Mouse actions (down, pressed, wheel) trigger redraw immediately.
- Mouse hover movement triggers redraw for non-terminal areas (throttled to 60 FPS); terminal hover movement is ignored to avoid full redraw.
- Terminal PTY polling happens only when data is available.

## Observed Hotspots / Risks
- Terminal renderer cost scales with dirty rows and glyph density; still heavy during full-screen updates.
- Any animation or continuous hover updates force a full frame redraw, including terminal.
- Terminal width is large (~190+ columns), so full redraw cost scales quickly with window size.
- Terminal resizing is handled in multiple code paths (window resize + drag), which can lead to frequent reflow.

## Recommendations (Priority Order)

### 1) Dirty-Row / Dirty-Rect Rendering for Terminal (DONE)
- Dirty rows are tracked and used to update the cached terminal texture.
- If scrollback offset is unchanged and no dirty rows are present, the terminal does not redraw.

### 2) Render-to-Texture Cache for Editor + Terminal (DONE)
- Terminal is cached in a texture and updated on dirty rows.
- Editor render-to-texture cache + dirty redraw are implemented (see ED-08).

### 3) Event-Driven Layout Invalidation
- Only recompute layout when:
  - window resized
  - terminal height changed
  - side nav width changed
- Avoid repeated layout arithmetic during idle frames.

### 4) Hover Invalidation Granularity
- Only mark redraw when hover state changes (enter/exit), not every pixel movement.
- Maintain per-widget hover state and use edge detection to reduce redraw requests.
  - We already started this by ignoring hover-only mouse movement over the terminal region since it has no hover UX; this reduced CPU spikes and validates the approach.

### 5) Terminal Input + Polling
- PTY polling is gated by `hasData()` (non-blocking).
- Read thread path still wakes on data; deeper event-driven wakeups remain optional.

### 6) Resize Throttling
- Debounce terminal resize while dragging (e.g., apply every N ms) to avoid excessive reflow.
- Keep a “pending size” and apply on drag end to reduce per-move recalculation.

## Suggested Next Actions
1) Add per-widget hover state tracking to limit redraw invalidations.
2) Consider partial-column damage to reduce overdraw for row-local edits.
3) Debounce terminal resize while dragging (apply pending size on drag end).

## Terminal Scrollback Status
- Scrollback is captured when the full screen scrolls and is exposed via a right-side scrollbar with drag and wheel support.
- Scrollback is cleared on column resize.

## Scrollback Next Steps
1) Add selection/copy behavior in scrollback view.
2) Add visual indicators for “scrolled back” state and quick-jump to live output.
3) Ensure scrollback is preserved across resize where possible (optional reflow strategy).

## Notes
- The bottom dock layout is simple and stable; performance issues stem primarily from redraw policy, not the layout structure itself.
- With dirty rendering or caching in place, hover and lightweight animations will be safe even with terminal visible.

## UI Thread/Backend Blocking Audit (2026-03-07)

Scope
- Audit `src/app/*`, `src/ui/widgets/*`, `src/terminal/core/*`, and `src/editor/*` for:
  - render-thread blocking on backend/session state
  - heavy compute and blocking I/O on the UI thread that can be moved or bounded

Confirmed high-impact hotspots
- Terminal draw holds `TerminalSession.state_mutex` for nearly the full draw path, including shaping-heavy loops.
  - `src/ui/widgets/terminal_widget_draw.zig`
- Terminal input path may block on the same mutex when input events are present.
  - `src/ui/widgets/terminal_widget_input.zig`
- Visible-terminal poll executes on the UI update path and iterates all tabs.
  - `src/app/visible_terminal_frame.zig`
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
  - `src/terminal/core/workspace.zig`
- On non-threaded PTY paths, parse work runs inline on UI thread.
  - `src/terminal/core/pty_io.zig`
- Highlighter init can run synchronous process execution (`spawnAndWait`) via frame-time prepare calls.
  - `src/app/editor_display_prepare.zig`
  - `src/editor/editor.zig`
- Search recompute reads full buffer and does expensive regex scans synchronously.
  - `src/editor/editor.zig`
- Ctrl+click file detect performs synchronous file open/stat/read on UI path.
  - `src/app/file_detect.zig`

Prioritized roadmap (implementation order)

1) Terminal lock-scope reduction (highest)
- Goal: remove long lock hold from `TerminalWidget.draw` and `TerminalWidget.handleInput`.
- Approach:
  - Copy/snapshot only required immutable view data under lock, then release lock before shaping + draw submission.
  - Keep lock hold for tiny state transitions only (scroll offset updates, selection writes).
- Acceptance:
  - No mutex lock around HarfBuzz shaping loops.
  - No regression in cursor/selection/dirty-row correctness under heavy output.

2) Terminal polling decoupling from UI update
- Goal: prevent per-frame all-tab poll work from elongating UI frame time.
- Approach:
  - Introduce poll budget + fairness (active tab first, bounded background tabs).
  - Move remaining poll work to background cadence where possible; UI thread only consumes ready snapshots/signals.
- Acceptance:
  - UI update phase remains bounded when many tabs produce output.
  - Active tab latency does not regress.

3) Highlighter init/offline bootstrap hardening
- Goal: remove `spawnAndWait` and other long setup from frame path.
- Approach:
  - Never run grammar bootstrap synchronously in frame/update/draw hooks.
  - Convert bootstrap/init to async state machine (pending, ready, failed) with non-blocking UI fallback.
- Acceptance:
  - Frame path contains no blocking child-process wait for grammar init.
  - Missing grammar UX remains clear and actionable.

4) Editor search compute offload and throttling
- Goal: avoid full-buffer synchronous scans on each query mutation.
- Approach:
  - Move regex/literal match recompute to worker task with cancellation by generation.
  - Keep main thread applying latest completed result only.
  - Add debounce for high-frequency query edits.
- Acceptance:
  - Typing into search remains responsive on large files.
  - Search highlight updates remain monotonic (no stale result overwrite).

5) UI-thread I/O cleanup for open detection
- Goal: eliminate synchronous filesystem probes on pointer/input path.
- Approach:
  - Replace direct text-file detection with deferred worker check or optimistic open + backend-side guard.
- Acceptance:
  - No file open/stat/read in immediate click handler path.

6) Continue bounded precompute strategy for editor caches
- Goal: preserve current budgeting and prevent accidental regressions.
- Approach:
  - Keep `precomputeHighlightTokens`, width, and wrap budgets explicit/configurable.
  - Add perf counters for consumed budget and spillover.
- Acceptance:
  - Budget knobs still cap per-frame cost in worst-case visible ranges.

## Phase 5 Checkpoint (2026-03-07)

Completed slices
- UI-PERF-01 (terminal draw lock scope):
  - `TerminalWidget.draw` now takes `TerminalSession` lock only long enough to refresh and copy render-cache state.
  - HarfBuzz shaping, glyph batching, kitty overlay draws, and cursor/selection overlays now run lock-free against widget-owned snapshot buffers.
  - Dirty-flag clear after draw now uses generation-guarded session helper (`clearDirtyIfGeneration(...)`) to avoid clearing newer state.
- UI-PERF-02 (terminal input lock contention):
  - `TerminalWidget.handleInput` no longer falls back to blocking lock waits after `tryLock` failure.
  - Lock-dependent non-critical work (hover/open/selection/scrollbar updates, OSC clipboard drain) is deferred when lock acquisition fails.
  - Key/focus input paths remain responsive under contention.
- UI-PERF-03 (poll budget/fairness):
  - Added workspace polling budget model (`TerminalWorkspace.PollBudget`) and bounded `pollBudgeted(...)`.
  - Active tab is polled first; background tabs are polled with bounded round-robin fairness.
  - Visible-terminal runtime now uses small budgets under active input and larger budgets when idle.
- UI-PERF-04 (grammar bootstrap off frame path):
  - Removed synchronous grammar bootstrap wait from highlighter init path.
  - Auto-bootstrap now runs in a detached worker with explicit state (`idle/running/succeeded/failed`).
  - Frame/update/draw path returns immediately while bootstrap is in progress.
- UI-PERF-06 (ctrl+click file-detect I/O cleanup):
  - Removed sync open/stat/read file-probe from immediate input callback.
  - Ctrl+click open path now uses no-I/O extension gating + guarded optimistic open.
- UI-PERF-07 (frame-phase terminal metrics + event-pressure refinement):
  - Added per-frame workspace poll metrics (active/background polled, budget usage, inspected background count, spillover/backlog hints).
  - Added per-frame terminal draw phase metrics (lock/snapshot time vs render time vs total draw time).
  - `input.latency` logs now include terminal poll/draw attribution when fresh metrics are available.
  - Terminal poll input-pressure hint is now driven by terminal-relevant activity (key/text/focus and meaningful mouse actions), not generic event count.
  - Passive terminal hover-only mouse movement is now skipped in visible-terminal widget input path when mouse reporting is off and ctrl-link intent is not active.

Remaining high-impact items
- UI-PERF-01: terminal draw lock-scope reduction (still highest risk for long render stalls).
- UI-PERF-05: search recompute offload/cancellation (still synchronous on UI thread).
- UI-PERF-07: frame-phase perf counters for lock wait/poll spillover.
- UI-PERF-08: heavy-output/large-file latency verification pass.
