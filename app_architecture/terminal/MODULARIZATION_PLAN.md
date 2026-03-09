# Terminal Modularization Plan

Date: 2026-01-24

Goal: split the terminal implementation into clear layers with a stable API surface, while preserving behavior and minimizing regressions.

## Scope
- Terminal core + protocol handling + screen model + snapshot API.
- Keep UI rendering in `src/ui/widgets/terminal_widget.zig` and renderer/font code in `src/ui/`.
- Preserve all current features (OSC/CSI/DCS, kitty graphics, scrollback, selection, input).

## Non-goals (for this phase)
- Major behavior changes.
- New protocol features or large refactors of renderer/font code.

## Constraints
- Test-first migration (add terminal tests before moving code).
- No feature removal; changes must be traceable to current behavior.
- Keep hot paths allocation-free and branch-light (per `DESIGN.md`).

## Target Layer Split (mapping to `app_architecture/terminal/DESIGN.md`)
1) UI Integration: `src/ui/widgets/terminal_widget.zig` (renderer + input mapping).
2) Snapshot API: `src/terminal/core/snapshot.zig` (immutable per-frame data).
3) PTY + IO: `src/terminal/io/*.zig` + optional `src/terminal/core/pty_driver.zig`.
4) VT Parser: `src/terminal/parser/*.zig` (byte stream to actions).
5) Screen Model: `src/terminal/model/*` (grid + scrollback + selection).
6) Protocol Handlers:
   - `src/terminal/protocol/csi.zig`
   - `src/terminal/protocol/osc.zig`
   - `src/terminal/protocol/dcs_apc.zig`
7) Kitty Graphics: `src/terminal/kitty/graphics.zig`
8) Input Encoding: `src/terminal/input/key_encoder.zig` + `src/terminal/input/key_encoding.zig` (CSI u/kitty mapping)

## Stable API Surface (public)
`TerminalSession` should expose only:
- lifecycle: `init`, `deinit`, `start`, `poll`, `resize`, `setCellSize`
- input: `sendKey`, `sendKeypad`, `sendChar`, `sendText`, `reportMouseEvent`
- state: `snapshot`, `selectionState`, `clearSelection`
- queries: `currentCwd`, `takeOscClipboard`, `hyperlinkUri`, `isAlive`
- locks: `lock`, `unlock`

`TerminalSnapshot` contract:
- Borrowed slices, valid until next snapshot.
- No per-frame allocations during render.

## Contract-First API Spec
Add `app_architecture/terminal/TERMINAL_API.md` with a per-API contract table:
- ownership/lifetime of returned data
- allocation behavior
- thread/concurrency expectations
- invariants (cursor bounds, scrollback rules, alt-screen rules)
- error semantics (error sets, when failures can occur)
- tests that cover the contract

## Feature Inventory (code-derived)
Before refactor, generate a feature list directly from current code:
- OSC/CSI/DCS/APC coverage from handler switch statements
- key encoding + modifier rules from input encoder
- kitty graphics actions supported (store/place/delete/clear)
Capture this list in `app_architecture/terminal/FEATURE_INVENTORY.md`.

## Test-First Safety Net
Approved fixture list (authoritative; 19 total):
- VT replay fixtures (18):
  - cursor_moves_basic
  - erase_line_and_display
  - insert_delete_chars
  - scroll_region_basic
  - sgr_16_256_truecolor
  - sgr_reverse_and_reset
  - alt_screen_enter_exit
  - scrollback_push
  - osc_title_bel
  - osc_cwd_st
  - osc_8_hyperlink_bel
  - osc_52_clipboard_bel
  - utf8_wide_and_combining
  - selection_basic_flow (harness API hooks)
  - kitty_store_place_delete
  - gping_redraw
  - nvim_overlay
  - vttest_wraparound
- Encoder unit test (1):
  - csi_u_encoder_bytes

Separation is enforced:
- VT replay tests
- harness API tests (selection)
- encoder unit tests (CSI-u)

## Baseline Fixture Capture (golden tests)
Add a replay harness to:
- feed a `.vt` fixture
- emit a deterministic snapshot string (grid + cursor + attrs + scrollback summary)
- store baseline goldens from current implementation before moving code

Approved replay harness outline is the design source of truth:
- snapshot string must encode title/cwd/clipboard/hyperlink tagging state
- grid encoding must be deterministic (blank cells, attrs encoding, wide-char handling, scrollback view)

## Layer Enforcement
Define explicit layer rules (e.g., UI → core → model/parser/io).
Add a lightweight build-time check to block forbidden imports or deep coupling.
Layer check implemented via `zig build check-terminal-imports` (see `tools/terminal_import_check.zig`).
Document allowed import directions before any refactor work begins.

## Migration Steps (incremental, each builds + tests)
1) Implement replay harness (per approved outline; no refactor).
2) Capture baseline golden fixtures from current implementation.
3) Generate `FEATURE_INVENTORY.md` derived from code.
4) Finalize `TERMINAL_API.md` with contracts tied to fixtures/tests.
5) Extract snapshot types into `core/snapshot.zig` (pure move + re-export).
6) Extract protocol handlers (CSI/OSC/DCS/APC) into `terminal/protocol`.
7) Extract kitty graphics into `terminal/kitty/graphics.zig`.
8) Move screen ops into `model/screen_ops.zig` or expand `model/screen.zig`.
9) Move selection state/extraction into `model/selection.zig`.
10) Reduce `terminal/core/terminal.zig` to a thin orchestrator.

Progress:
- Completed step 5 (snapshot types + encoding extracted into `terminal/core/snapshot.zig`).
- Completed step 6 (protocol handlers extracted into `terminal/protocol`).
- Completed step 7 (kitty graphics extracted into `terminal/kitty/graphics.zig`).
- Completed step 8 (screen ops expanded in `terminal/model/screen.zig`).
- Completed step 9 (selection types/state in `terminal/model/selection.zig`).
- Completed step 10 (terminal core now a thin orchestrator; screen helpers consolidated under `terminal/model/screen/` with facade).
- Scrollback push ordering aligned with Ghostty/Kitty; `scrollback_push` golden updated.
- Completed step 3 (feature inventory captured in `app_architecture/terminal/FEATURE_INVENTORY.md`).
- Migration step: extracted terminal render cache to `src/terminal/core/render_cache.zig` (no behavior change).
- Migration step: extracted palette + dynamic color handling to `src/terminal/protocol/palette.zig` (no behavior change).
- Migration step: extracted OSC semantic prompt + user-var handling to `src/terminal/protocol/osc_semantic.zig` (no behavior change).
- Migration step: extracted OSC clipboard handling to `src/terminal/protocol/osc_clipboard.zig` (no behavior change).
- Migration step: extracted OSC CWD normalization + decode helpers to `src/terminal/protocol/osc_cwd.zig` and `src/terminal/protocol/osc_util.zig` (no behavior change).
- Migration step: extracted OSC hyperlink handling to `src/terminal/protocol/osc_hyperlink.zig` (no behavior change).
- Migration step: extracted OSC title handling to `src/terminal/protocol/osc_title.zig` (no behavior change).
- Migration step: extracted mouse reporting helpers to `src/terminal/input/mouse_report.zig` (no behavior change).
- Migration step: extracted key encoding helpers to `src/terminal/input/key_encoding.zig` (no behavior change).
- Migration step: extracted keypad mappings to `src/terminal/input/keypad.zig` (no behavior change).
- Migration step: extracted PTY start/poll to `src/terminal/core/pty_io.zig` (no behavior change).
- Migration step: extracted I/O thread helpers to `src/terminal/core/io_threads.zig` (no behavior change).
- Migration step: extracted view cache pipeline to `src/terminal/core/view_cache.zig` (no behavior change).
- Migration step: extracted resize + reflow logic to `src/terminal/core/resize_reflow.zig` (no behavior change).
- Migration step: extracted scrolling helpers to `src/terminal/core/scrolling.zig` (no behavior change).
- Migration step: extracted selection helpers to `src/terminal/core/selection.zig` (no behavior change).
- Migration step: extracted control handlers to `src/terminal/core/control_handlers.zig` (no behavior change).
- Migration step: extracted parser glue to `src/terminal/core/parser_hooks.zig` (no behavior change).
- Migration step: extracted input mode helpers to `src/terminal/core/input_modes.zig` (no behavior change).
- Migration step: extracted hyperlink table helpers to `src/terminal/core/hyperlink_table.zig` (no behavior change).
- Migration step: extracted reset/save/restore helpers to `src/terminal/core/state_reset.zig` (no behavior change).
- Migration step: extracted scrollback accessors to `src/terminal/core/scrollback_view.zig` (no behavior change).
- Follow-up (2026-03-09): expanded `app_architecture/terminal/TERMINAL_API.md` with an explicit boundary contract for runtime/protocol/model/publication/widget ownership.
- Follow-up (2026-03-09): removed the file-global visible-terminal poll input-activity hint; terminal input pressure is now passed explicitly into `poll_visible_terminal_sessions_runtime.handle(...)`.
- Follow-up (2026-03-09): moved terminal idle/pacing bookkeeping out of `frame_render_idle_runtime` file globals and into `AppState` so scheduler state is instance-owned.
- Follow-up (2026-03-09): removed the stale snapshot-based hover/open widget path so terminal hover/open now has one authoritative visible-cache seam.
- Follow-up (2026-03-09): removed the dead `TerminalSession.markDirty()` / `Screen.markDirtyAll()` escape-hatch APIs and their dedicated full-dirty reasons.
- Follow-up (2026-03-09): removed additional dead leftovers from the old snapshot/open seam (`TerminalSession.clearDirty()` and the unused snapshot row helper in `terminal_widget_open.zig`).
- Follow-up (2026-03-09): removed the dead unbounded `TerminalWorkspace.pollAll()` API so workspace polling surface now matches the budgeted scheduler design.
- Follow-up (2026-03-09): extracted workspace polling/fairness implementation into `src/terminal/core/workspace_polling.zig` so `workspace.zig` moves closer to tab/session ownership rather than scheduling policy.
- Follow-up (2026-03-09): removed the now-dead public `TerminalWorkspace.pollBudgeted(...)` surface after `pollForFrame(...)` became the workspace-owned polling contract used by app runtime.
- Follow-up (2026-03-09): removed the public `TerminalWorkspace.PollBudget` type after poll budgets became an internal workspace-polling detail instead of part of the live runtime contract.
- Follow-up (2026-03-09): added explicit read-only workspace generation/data queries so app runtime pacing code can avoid raw session-pointer access when it only needs polling/publication state.
- Follow-up (2026-03-09): added explicit workspace cwd/close-confirm query helpers and rewired read-only app callers off `sessionAt(...)` / `activeSession()` where they only needed derived state.
- Follow-up (2026-03-09): extracted terminal frame pacing/latency/generation observation into `src/app/terminal_frame_pacing_runtime.zig` so `frame_render_idle_runtime.zig` acts as a coordinator instead of embedding terminal scheduler policy inline.
- Follow-up (2026-03-09): grouped terminal frame pacing bookkeeping into `AppState.terminal_frame_pacing` so runtime scheduler state stops leaking across the top-level app state as unrelated scalar fields.
- Follow-up (2026-03-09): removed the dead frame-pacing `pressure_since` timestamp after the runtime extraction confirmed it was no longer read by any scheduler path.
- Follow-up (2026-03-09): extracted visible-terminal poll budget/pressure/publication detection into `src/app/terminal_poll_runtime.zig` so `poll_visible_terminal_sessions_runtime.zig` stops embedding terminal polling policy inline.
- Follow-up (2026-03-09): moved concrete per-frame workspace poll budgets behind `TerminalWorkspace.pollForFrame(...)` so app runtime no longer owns those fairness constants directly.
- Follow-up (2026-03-09): introduced `TerminalSession.acknowledgePresentedGeneration(...)` so widget draw no longer manually composes presented-generation publication with dirty-retirement calls.
- Follow-up (2026-03-09): moved sync-updates dirty-retirement choice behind `TerminalSession.acknowledgePresentedGeneration(...)` so widget draw no longer supplies that policy bit either.
- Follow-up (2026-03-09): removed the old paired generation-guarded dirty-clear APIs from the public session surface and collapsed them into one backend-owned retirement helper behind `acknowledgePresentedGeneration(...)`.
- Follow-up (2026-03-09): routed common input-mode snapshot updates through explicit `input_modes` setters so CSI mode toggles no longer open-code field mutation plus `updateInputSnapshot()` at each call site.
- Follow-up (2026-03-09): extracted DECSTR input-mode reset into `input_modes.resetInputModes(...)` so soft reset stops duplicating snapshot-owned field resets inline.
- Follow-up (2026-03-09): routed alt-screen transitions through `setActiveScreenMode(...)` so active-screen publication and snapshot refresh stop being open-coded in enter/exit paths.

## Regression Checklist (keep in sync)
- OSC coverage: 0/2/7/8/10/11/12/19/52 + XTGETTCAP.
- SGR: 16/256/truecolor + bold/reverse.
- CSI: cursor, erase, insert/delete, scroll region, DA/DSR.
- Alt screen state + scrollback rules.
- Kitty graphics (payload decode as currently implemented, placements, delete actions).
- Key input: CSI u/kitty flags + modifier handling.

## Refactor Rules (hard)
- Extraction-only until tests and goldens pass.
- No behavior changes during file moves; any semantic change requires a separate, test-driven step.
- Keep diffs small and reviewable; do not move multiple subsystems at once.
- Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.

## Decisions Locked
- Approved fixture list (19 total) is authoritative.
- Replay harness snapshot format is fixed by the approved outline.
- Tests + goldens gate all refactors.
- Extraction-only means no renames, no cleanup, no behavior changes.

## Current Architectural Hotspots (2026-03-09)

These are the large remaining smells after the redraw/rain cleanup work. They are
ordered by how much they constrain future correctness and simplification work.

1) `TerminalSession` remains a god object.
- File: `src/terminal/core/terminal_session.zig`
- It still owns PTY/threading, parser/runtime state, both screens, history, kitty state,
  render caches, redraw publication state, input snapshot state, and multiple UI-facing APIs.
- This prevents a clean contract between model, runtime, and presentation.

2) Render publication ownership is still split.
- Files:
  - `src/terminal/core/view_cache.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/app/frame_render_idle_runtime.zig`
- `view_cache` is no longer just a cache builder; it also embeds redraw policy
  heuristics, selection overlay publication, row-hash refinement, viewport-shift
  publication, and kitty ordering.
- `terminal_widget_draw` still performs backend-facing lifecycle work such as
  pending-cache service, presented-generation ack, and dirty clearing.

3) Scheduler ownership is still spread across app runtime helpers and workspace policy.
- Files:
  - `src/app/frame_render_idle_runtime.zig`
  - `src/app/terminal_frame_pacing_runtime.zig`
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
  - `src/terminal/core/workspace.zig`
- Poll cadence, backlog hints, draw cadence, and active/background fairness are
  still split across multiple modules even though the obvious file-global runtime
  state has now been removed.

4) Input snapshot publication is manual and drift-prone.
- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/protocol/csi.zig`
  - `src/terminal/core/input_modes.zig`
- The current `input_snapshot` design works, but many protocol/mode branches must
  remember to call `updateInputSnapshot()`. The most repetitive CSI toggles now flow
  through explicit setters, but the design is still easy to drift and hard to audit.

5) Widget input/draw code still carries backend and app policy.
- Files:
  - `src/ui/widgets/terminal_widget_input.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/ui/widgets/terminal_widget.zig`
- The widget is still larger than a thin presenter: it owns cache copies, hover/open
  policy, selection behavior, scrollbar policy, kitty upload scheduling, and dirty ack.

6) Protocol layer boundaries are still implicit.
- Files:
  - `src/terminal/protocol/csi.zig`
  - `src/terminal/protocol/osc.zig`
  - `src/terminal/core/parser_hooks.zig`
- Protocol modules use `anytype self` and mutate deep session state through implicit
  contracts rather than a narrow explicit interface.

7) Kitty graphics remains a concentrated risk surface.
- File: `src/terminal/kitty/graphics.zig`
- The module still combines protocol parsing, payload assembly, memory lifecycle,
  placement management, dirty-region derivation, and fallback invalidation behavior.

## Hotspot Refresh (2026-03-09 Evening Review)

This review was done against current `main`, after the rain/render cleanup landed.
These are the highest-signal remaining smells that still look structurally important.

1) Presentation ack and dirty retirement are still triggered from widget draw.
- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/terminal/core/terminal_session.zig`
- `TerminalSession.acknowledgePresentedGeneration(...)` improved the seam, but the
  widget still decides when presentation is acknowledged. Backend dirty retirement is
  therefore still downstream of UI draw execution instead of being owned by a clearer
  presentation/publication boundary.

2) PTY write serialization is still inconsistent.
- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/input_modes.zig`
  - `src/terminal/protocol/csi.zig`
- Normal input/reporting paths use `pty_write_mutex`, but several protocol reply/query
  paths still write directly to PTY. That leaves the terminal with more than one write
  contract and makes output ordering vulnerable to interleaving.

3) Palette/default-color mutation still has an unlocked path.
- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/app/terminal_theme_apply.zig`
  - `src/terminal/protocol/palette.zig`
- `setDefaultColors(...)` mutates screen/history state and republishes the view cache
  without taking the session mutex, while it is reachable from both app theme changes
  and OSC dynamic-color handling. That is still an inconsistent state/publication seam.

4) Workspace/runtime scheduling is cleaner, but frame policy still lives partly inside core.
- Files:
  - `src/terminal/core/workspace_polling.zig`
  - `src/app/terminal_poll_runtime.zig`
  - `src/app/terminal_frame_pacing_runtime.zig`
- Poll budgets, active/background fairness, and backlog hints are still partly encoded
  inside core polling logic rather than being cleanly injected as runtime policy.

5) Protocol/parser contracts remain implicit and stale investigation probes still exist.
- Files:
  - `src/terminal/core/parser_hooks.zig`
  - `src/terminal/parser/parser.zig`
  - `src/terminal/protocol/csi.zig`
  - `src/terminal/protocol/osc.zig`
  - `src/terminal/core/view_cache.zig`
- These modules still rely on `anytype self` instead of an explicit session/protocol
  surface, and there are still probe-style logging leftovers in hot paths
  (`terminal.trace.scope`, `terminal.inputpath`, `terminal.ui.row_fullwidth_origin`).

6) Kitty graphics is still too broad a module even after the incremental damage cleanup.
- File: `src/terminal/kitty/graphics.zig`
- The backend now publishes kitty damage much better than before, but the module still
  combines protocol parsing, payload loading, decode, storage, placement graph updates,
  dirty-region derivation, and fallback/error policy in one ownership surface.

## Strict Cleanup Queue (2026-03-09)

This is the ordered execution list for terminal cleanup work on `main`.
The intent is to take these top-to-bottom unless new evidence forces a reorder.
Statuses are strict:
- `todo`: not started
- `in_progress`: active focus
- `done`: landed and documented

1) Presentation/publication ownership cleanup
- status: `done`
- priority: `P0`
- scope:
  - move presented-generation acknowledgement and dirty retirement out of widget draw initiation
  - define a backend-owned presentation/publication boundary
  - keep `terminal_widget_draw` as a consumer of published state, not the owner of backend retirement policy
- primary files:
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/view_cache.zig`
- progress:
  - 2026-03-09: first slice landed on feature branch work: `terminal_widget_draw` now reports draw/presentation outcome instead of retiring backend dirty state inline, and terminal surface/runtime finishes presentation after the draw call returns.
  - 2026-03-09: second slice landed on feature branch work: published render-cache capture now flows through `TerminalSession.copyPublishedRenderCache(...)`, so draw stops open-coding session lock + pending-cache service + live-cache copy.
  - 2026-03-09: third slice landed on feature branch work: session now returns a `PresentedRenderCache` token and owns the retirement eligibility rule through `retirePresentedRenderCache(...)`, so draw/runtime no longer decide dirty-retirement eligibility inline from ad-hoc `updated/dirty` checks.
  - 2026-03-09: fourth slice landed on feature branch work: `TerminalWidget` no longer stores pending presentation outcome as widget state; draw now returns the outcome directly and terminal surface/runtime passes it through explicitly to presentation retirement.
  - 2026-03-09: fifth slice landed on feature branch work: render-cache capture moved out of `terminal_widget_draw` and into the widget wrapper, and mouse-reporting visibility is now published in `RenderCache`, so draw depends less on live session state during presentation.
  - 2026-03-09: sixth slice landed on feature branch work: alt-exit timing consumption moved out of the draw module and into the post-draw presentation finish path, removing the last direct live-session atomic access from `terminal_widget_draw`.
  - 2026-03-09: seventh slice landed on feature branch work: the post-draw presentation feedback contract moved into `TerminalSession.completePresentationFeedback(...)`, so widget flow no longer owns backend dirty-retirement or alt-exit presentation policy.

2) PTY write contract unification
- status: `done`
- priority: `P0`
- scope:
  - make all terminal-originated PTY writes obey one serialization contract
  - remove direct write paths that bypass `pty_write_mutex`
  - cover replies, queries, and input/reporting under the same rule
- primary files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/input_modes.zig`
  - `src/terminal/protocol/csi.zig`
  - other direct PTY reply writers as discovered
- progress:
  - 2026-03-09: session now owns a locked PTY writer token (`lockPtyWriter(...)`) plus the single-write helper (`writePtyBytes(...)`), and all terminal-originated production writes now flow through that contract instead of bypassing `pty_write_mutex`.
  - 2026-03-09: DCS/CSI/OSC/kitty reply paths and input-mode queries were rewired onto the session-owned write contract, while reply-byte unit tests were kept intact by teaching the test harnesses the same locked-writer surface.

3) Session state/publication locking cleanup
- status: `done`
- priority: `P0`
- scope:
  - remove unlocked mutation/publication paths such as default-color/theme publication
  - make model mutation + cache publication follow one locking contract
  - eliminate mixed locked/unlocked session mutation semantics where they still exist
- primary files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/protocol/palette.zig`
  - `src/app/terminal_theme_apply.zig`
- progress:
  - 2026-03-09: first slice landed on feature branch work: default-color publication now has an explicit `setDefaultColorsLocked(...)` contract for parser-owned state mutations, and app-side theme application now uses `applyThemePalette(...)` so palette capture, default-color mutation, ANSI replacement, and remap happen under one session lock instead of a partly unlocked sequence.
  - 2026-03-09: second slice landed on feature branch work: OSC palette and dynamic-color protocol handlers now mutate session palette/default state through explicit locked helpers (`setPaletteColorLocked(...)`, `resetAllPaletteColorsLocked(...)`, `setDynamicColorCodeLocked(...)`) instead of reaching into raw session fields ad hoc.
  - 2026-03-09: third slice landed on feature branch work: parser-owned synchronized-update and DECCOLM mode changes now call explicit locked session helpers (`setSyncUpdatesLocked(...)`, `setColumnMode132Locked(...)`) instead of generic mutators with ambiguous lock ownership, aligning the protocol/session seam more closely with kitty-style parser-held mutation and Ghostty-style explicit lock contracts.
  - 2026-03-09: fourth slice landed on feature branch work: public scrollback viewport mutation (`setScrollOffset(...)`, `scrollBy(...)`) and cell-size updates now take the session lock, while resize/reflow uses explicit locked viewport helpers when it already owns the lock. This removes another UI-thread mutation path that previously raced parser-owned session state.
  - 2026-03-09: fifth slice landed on feature branch work: terminal selection mutation now follows the same split as other shared session state. UI-facing selection APIs lock, while parser-owned/internal paths use explicit locked helpers (`clearSelectionLocked(...)`, `startSelectionLocked(...)`, `updateSelectionLocked(...)`, `finishSelectionLocked(...)`) when they already hold the session mutex.

4) `TerminalSession` surface reduction
- status: `in_progress`
- priority: `P1`
- scope:
  - shrink `TerminalSession` toward an orchestrator instead of a universal owner
  - reduce raw mutable public surface
  - split or hide APIs that exist only because boundaries are still blurred
- primary files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/terminal.zig`
- progress:
  - 2026-03-09: first slice started on feature branch work: app/UI consumers are being moved off borrowed session-owned clipboard/link/title/cwd reads and onto explicit copy-out session APIs with caller-owned buffers. This begins shrinking the most fragile external `TerminalSession` surface before broader orchestrator reduction.
  - 2026-03-09: second slice started on feature branch work: workspace tab metadata no longer borrows `title/cwd` directly from a live session. This started with `TerminalWorkspace.copyMetadataAt(...)`, and later item-5 tab-sync work replaced that indexed seam with `copyTabSyncState(...)`.
  - 2026-03-09: third slice started on feature branch work: new-terminal launch cwd no longer borrows the active session cwd through workspace. `TerminalWorkspace.copyActiveSessionCwd(...)` now copies into caller-owned storage before runtime uses it as launch input.
  - 2026-03-09: fourth slice started on feature branch work: FFI scrollback export no longer walks borrowed row slices from a live session. `TerminalSession.copyScrollbackRow(...)` now copies rows into caller-owned storage before the bridge maps them into ABI cells.
  - 2026-03-09: fifth slice started on feature branch work: widget-side selection/plain/ANSI export paths no longer walk borrowed scrollback rows directly. They now use `TerminalSession.copyScrollbackRow(...)` for history rows, reducing another external dependency on live session-owned row slices.
  - 2026-03-09: sixth slice started on feature branch work: snapshot now publishes `scrollback_count`, `scrollback_offset`, and `selection`, and widget/input paths are being rewired to prefer snapshot/render-cache metadata over separate live session reads for the same state.
  - 2026-03-09: seventh slice started on feature branch work: terminal text export is now backend-owned. Selection/plain/ANSI export moved out of `terminal_widget.zig` into `src/terminal/core/text_export.zig` and is exposed through `TerminalSession`, so app shortcuts and pager flow through terminal core instead of widget-owned serialization.
  - 2026-03-09: eighth slice started on feature branch work: the new terminal-owned export seam is now exposed to FFI through string-returning bridge/C APIs for selection text plus plain/ANSI scrollback dumps, and obsolete borrowed session reads (`currentTitle`, `currentCwd`, `scrollbackRow`, `scrollOffset`, `selectionState`) were deleted from the public `TerminalSession` surface.
  - 2026-03-09: ninth slice started on feature branch work: scrollback range export is now backend-owned as well. `copyScrollbackRange(...)` moved row-count validation and contiguous history-cell assembly out of the FFI bridge and into terminal core, so the bridge only marshals ABI cells instead of implementing a second scrollback paging contract.
  - 2026-03-09: tenth slice started on feature branch work: the old row-by-row public history seam (`copyScrollbackRow(...)`) was deleted after all real callers moved to backend-owned range/text export contracts. Remaining tests now validate history through `copyScrollbackRange(...)` instead of a special-case row helper.
  - 2026-03-09: eleventh slice started on feature branch work: leftover naked geometry/count queries were narrowed again. Public `gridRows(...)`, `gridCols(...)`, and `scrollbackCount(...)` were removed from `TerminalSession`, replaced by a backend-owned `scrollbackInfo(...)` metadata contract used by FFI instead of a raw count getter.
  - 2026-03-09: twelfth slice started on feature branch work: separate FFI title/cwd/scrollback-count getters were replaced with one backend-owned metadata contract. `TerminalSession.copyMetadata(...)` now publishes title, cwd, scrollback count/offset, alive, and exit status in one call, and FFI/workspace callers were rewired onto that instead of stitching those fields together piecemeal.
  - 2026-03-09: thirteenth slice started on feature branch work: the leftover split title/cwd copy helpers (`copyCurrentTitle(...)`, `copyCurrentCwd(...)`) were deleted. Workspace launch-cwd lookup and ctrl-open path resolution now use the same backend-owned `copyMetadata(...)` contract as FFI instead of keeping a second public metadata seam alive.
  - 2026-03-09: fourteenth slice started on feature branch work: the public `childExitCode(...)` session getter was deleted after the FFI bridge moved fully onto `copyMetadata(...)` for exit-status reads and derived-event sync. That removes another raw process-state escape hatch that only survived for older FFI layering.

5) Workspace/session boundary tightening
- status: `in_progress`
- priority: `P1`
- scope:
  - keep reducing raw `TerminalSession*` escape paths from `TerminalWorkspace`
  - replace raw app/runtime access with explicit workspace contracts where possible
  - keep mutable session access narrow and intentional
- primary files:
  - `src/terminal/core/workspace.zig`
  - `src/app/terminal_active_session.zig`
  - `src/app/new_terminal_runtime.zig`
  - remaining workspace/session consumers
- progress:
  - 2026-03-09: first slice started on feature branch work: app clipboard shortcuts stopped resolving raw sessions through workspace entirely and now operate on the already-resolved active widget/session. The dead `src/app/terminal_active_session.zig` resolver was deleted.
  - 2026-03-09: second slice started on feature branch work: workspace tab creation now has an explicit mutable creation contract (`createTabWithSession(...)`) so app runtime no longer does `createTab(...)` followed by a separate `activeSession()` lookup just to configure the newly-created tab.
  - 2026-03-09: third slice started on feature branch work: `TerminalWorkspace.sessionAt(...)`, `activeSession(...)`, and `tabsSlice(...)` stopped being part of the live public app/runtime surface. The remaining raw session helpers are now internal to `workspace.zig`, and the dead `TerminalTab` re-export was removed from `terminal/core/terminal.zig`.
  - 2026-03-09: fourth slice started on feature branch work: terminal tab-bar sync now consumes one workspace-owned snapshot contract (`copyTabSyncState(...)`) instead of stitching together `tabCount(...)`, `tabIdAt(...)`, `copyMetadataAt(...)`, and `activeTabId(...)`. The per-index `copyMetadataAt(...)` seam was deleted once the tab-bar path moved over.
  - 2026-03-09: fifth slice started on feature branch work: window-close confirm routing now consumes `firstConfirmCloseTab(...)` from workspace instead of scanning tabs by index in app runtime, and the now-dead per-index helper `shouldConfirmCloseAt(...)` was deleted.

6) Runtime scheduling ownership cleanup
- status: `done`
- priority: `P1`
- scope:
  - push frame-policy and fairness choices to clearer runtime-owned boundaries
  - reduce baked-in scheduling heuristics inside terminal core polling code
  - keep workspace focused on tab ownership plus bounded polling contract
- primary files:
  - `src/terminal/core/workspace_polling.zig`
  - `src/app/terminal_poll_runtime.zig`
  - `src/app/terminal_frame_pacing_runtime.zig`
- progress:
  - 2026-03-09: first slice started on feature branch work: workspace now owns active-frame scheduling observation through `activeFrameState()` and poll-result publication through `PollFrameResult`. Runtime pacing/poll helpers no longer reconstruct those decisions from separate getters plus app-side pre/post generation comparisons, and the old raw getters (`activeSessionHasData`, `activeSessionPublishedGeneration`, `activeSessionCurrentGeneration`, `publishedGenerationAt`) were deleted.
  - 2026-03-09: second slice started on feature branch work: runtime now owns poll profile selection again. `terminal_poll_runtime` chooses a `PollPolicy` and workspace executes it, so `workspace_polling` no longer hardcodes the input-vs-idle budget table internally.
  - 2026-03-09: third slice started on feature branch work: terminal idle/backoff bookkeeping moved fully under `TerminalFramePacingState`. The old generic `AppState.idle_frames` counter was deleted, and `frame_render_idle_runtime` now drives idle progression through explicit pacing hooks (`noteDraw`, `noteIdle`) instead of mutating terminal sleep state directly.
  - 2026-03-09: fourth slice landed on main-line work: runtime poll and sleep cadence now use explicit profiles (`default_poll_profiles`, `default_sleep_policy`) instead of anonymous magic constants embedded in the hot path, matching the intended Ghostty-style split where terminal core publishes state and runtime owns draw aggressiveness.

7) Input publication redesign
- status: `in_progress`
- priority: `P1`
- scope:
  - replace manual `updateInputSnapshot()` publication shape with a narrower explicit mode/publication boundary
  - remove dual-source-of-truth drift between raw fields and atomic snapshot reads
  - make lock expectations explicit for input-facing state
- primary files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/input_modes.zig`
  - `src/terminal/protocol/csi.zig`
- progress:
  - 2026-03-09: first slice landed on feature-branch work: generic `TerminalSession.updateInputSnapshot()` was removed from the public session surface, input snapshot publication now flows through `input_modes.publishSnapshot(...)`, and `resetState()` now republishes keypad/cursor input state so parser resets cannot silently drift from the atomic input snapshot.
  - 2026-03-09: second slice landed on feature-branch work: input-mode setters now have explicit locked and unlocked variants, CSI/ESC parser mutation paths use the `*Locked` variants, and `feedOutputBytes(...)` now acquires `state_mutex` before parser dispatch so parser-owned mode mutation consistently runs under one lock contract.
  - 2026-03-09: third slice landed on feature-branch work: DECRQM/input-mode read paths now consume explicit session query helpers instead of raw input fields, and SGR-pixel mouse mode (`1016`) is now published in the atomic input snapshot alongside the other input-facing mode bits.
  - 2026-03-09: fourth slice landed on feature-branch work: hard reset (`RIS`, `ESC c`) now uses a locked reset path and resets the full input-mode subset coherently via `resetInputModesLocked(...)` instead of ad hoc field pokes, with regression coverage for parser-fed `RIS` clearing both input modes and screen contents.
  - 2026-03-09: fifth slice landed on feature-branch work: kitty keyboard protocol (`CSI >/< /=/? ... u`) no longer calls lock-taking key-mode APIs from the parser-held state lock. Parser-owned key-mode push/pop/modify/query now use explicit `*Locked` paths, fixing the same nested-lock freeze class that showed up during TUI startup in `nvim`, `lazygit`, and `codex-cli`.

8) Widget input/draw policy reduction
- status: `todo`
- priority: `P2`
- scope:
  - reduce `terminal_widget_input` and `terminal_widget_draw` to presentation/orchestration only
  - move backend/app policy out of widget code
  - keep widget-local state only where it is truly UI-owned
- latest note:
  - 2026-03-09: fixed a real nested-lock bug in `terminal_widget_input` scrollback selection/scroll handling by using `*Locked` session helpers inside the widget-owned session lock; scrollback mouse selection should remain stable instead of freezing the tab
- progress:
  - 2026-03-09: first slice landed on feature-branch work: word-boundary, row-content, and selection-position ordering semantics used by terminal selection gestures moved out of `terminal_widget_input` and into model-owned code (`selection_semantics.zig`), so the widget consumes backend selection rules instead of embedding them inline.
  - 2026-03-09: second slice landed on feature-branch work: repeated widget-owned `start/update/finish` selection sequencing for word/line gestures moved behind backend `selectRangeLocked(...)`, reducing selection mutation choreography in `terminal_widget_input` and consolidating cache publication for those gestures in terminal core.
  - 2026-03-09: third slice landed on feature-branch work: widget-owned “clear if active”, “finish if active”, single-cell selection start, and “reset scrollback to live bottom” mutation rules moved behind backend helpers, so `terminal_widget_input` carries less direct session-state sequencing for common scrollback/selection paths.
  - 2026-03-09: fourth slice landed on feature-branch work: drag-selection range ordering, late-start update, and drag autoscroll mutation now go through backend helpers (`selectOrderedRangeLocked`, `selectOrUpdateCellLocked`, `scrollSelectionDragLocked`) instead of widget-local sequencing.
  - 2026-03-09: fifth slice landed on feature-branch work: wheel-scroll and scrollbar drag mutation policy now live behind backend scrollback helpers (`scrollWheelLocked`, `setScrollOffsetFromNormalizedTrackLocked`) instead of widget-local delta and offset mapping.
  - 2026-03-09: sixth slice landed on feature-branch work: multi-click selection gesture policy now lives behind backend helpers (`beginClickSelectionLocked`, `extendGestureSelectionLocked`) and one backend-defined `SelectionGesture` state object, replacing widget-local anchor-field assembly and mode-specific range mutation logic.
  - 2026-03-09: seventh slice landed on feature-branch work: the widget no longer peeks at row-content semantics to decide whether click/drag selection can start or extend. `beginClickSelectionLocked(...)` now returns an explicit click result, and `selectOrUpdateCellInRowLocked(...)` owns late-start row-content gating in terminal core.
  - 2026-03-09: eighth slice landed on feature-branch work: terminal scrollbar drag state (`drag_active`, grab offset) moved out of generic app runtime state and onto `TerminalWidget`, deleting the threaded app/runtime parameter plumbing for terminal-only UI state.
  - 2026-03-09: ninth slice landed on feature-branch work: left-button release reset is now authoritative in one path in `terminal_widget_input`, clearing scrollbar drag + selection drag/gesture state in one place and removing duplicated in-branch reset logic.
  - 2026-03-09: tenth slice landed on feature-branch work: selection drag-threshold and left-release reset state transitions were extracted into explicit widget-input helpers (`selectionDragIsActive`, `resetLeftDragState`) to reduce branch-local state mutation drift while preserving behavior.
- primary files:
  - `src/ui/widgets/terminal_widget_input.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/ui/widgets/terminal_widget.zig`

9) Protocol/parser boundary typing cleanup
- status: `in_progress`
- priority: `P2`
- scope:
  - replace implicit `anytype self` protocol/session contracts with a narrower explicit facade
  - reduce hidden ownership and mutation assumptions across parser/protocol code
  - improve testability of protocol handling in isolation
- primary files:
  - `src/terminal/core/parser_hooks.zig`
  - `src/terminal/parser/parser.zig`
  - `src/terminal/protocol/csi.zig`
  - `src/terminal/protocol/osc.zig`
- progress:
  - 2026-03-09: first slice landed on feature-branch work: DCS/APC protocol handling now consumes an explicit session facade (`protocol/dcs_apc.zig:SessionFacade`) instead of direct `anytype self` mutation. Parser hooks now adapt terminal session state into that facade at the boundary.
  - 2026-03-09: second slice landed on feature-branch work: OSC parser dispatch now consumes an explicit session facade (`protocol/osc.zig:SessionFacade`) at the parser boundary. OSC sub-handlers still use internal `anytype` contracts behind that adapter and remain queued for follow-on narrowing.
  - 2026-03-09: third slice landed on feature-branch work: CSI parser dispatch now also consumes an explicit session facade (`protocol/csi.zig:SessionFacade`) at the parser boundary. Existing CSI behavior remains unchanged behind the adapter and internal handler narrowing remains queued.
  - 2026-03-09: fourth slice landed on feature-branch work: OSC title and hyperlink sub-handlers now run through explicit local facades (`osc_title.zig:SessionFacade`, `osc_hyperlink.zig:SessionFacade`) instead of raw `anytype` mutation, reducing implicit state-coupling inside protocol internals.
  - 2026-03-09: fifth slice landed on feature-branch work: OSC cwd normalization path now runs through explicit local facades (`osc_cwd.zig:SessionFacade`, `osc_util.zig:SessionFacade`) instead of raw session mutation in helper code, narrowing another OSC internal state seam.
  - 2026-03-09: sixth slice landed on feature-branch work: OSC 52 clipboard handling now runs through an explicit local facade (`osc_clipboard.zig:SessionFacade`) for clipboard-buffer mutation and reply writes, removing another raw `anytype` protocol-internal mutation path.
  - 2026-03-09: seventh slice landed on feature-branch work: OSC semantic prompt/user-var dispatch now also runs through an explicit local facade (`osc_semantic.zig:SessionFacade`) at the `osc.zig` boundary, reducing direct raw `anytype` calls across OSC submodules.
  - 2026-03-09: eighth slice landed on feature-branch work: OSC palette/dynamic-color handling now runs through an explicit local facade (`palette.zig:SessionFacade`) for palette state reads/writes and reply writes, removing another raw `anytype` OSC-internal mutation path.
  - 2026-03-09: ninth slice landed on feature-branch work: OSC kitty clipboard (`5522`) dispatch now runs through an explicit local facade (`osc_kitty_clipboard.zig:SessionFacade`) at the `osc.zig` boundary, matching the typed dispatch shape used by other OSC submodules.
  - 2026-03-09: tenth slice landed on feature-branch work: kitty paste-event emission now also runs through the `osc_kitty_clipboard` facade (`sendPasteEventMimes(...)`), and terminal-session paste path now calls that typed surface instead of directly binding to raw `anytype` helper calls.

10) Investigation/probe residue cleanup
- status: `in_progress`
- priority: `P2`
- scope:
  - remove stale hot-path probe logging that survived the rain investigation
  - keep only logs that still serve an operational/debugging contract
- primary files:
  - `src/terminal/core/parser_hooks.zig`
  - `src/terminal/core/view_cache.zig`
  - `src/terminal/protocol/csi.zig`
- progress:
  - 2026-03-09: first slice landed on feature-branch work: removed the hot-path `terminal.trace.scope` probe branch from `handleCodepoint(...)` in `parser_hooks.zig` (the `cp == 0x2502` logging hook), reducing parser-side investigation residue in the steady-state write path.
  - 2026-03-09: second slice landed on feature-branch work: removed `terminal.inputpath` CSI probe logs from hot cursor/erase handlers (`CUF`, `CUB`, `EL`) so protocol dispatch no longer emits per-sequence investigation noise in steady-state TUI traffic.
  - 2026-03-09: third slice landed on feature-branch work: demoted remaining high-frequency protocol trace logs from `.info` to `.debug` across CSI/OSC/APC and OSC reply emitters, preserving diagnostics while preventing default-info log spam on normal terminal traffic.
  - 2026-03-09: fourth slice landed on feature-branch work: removed `terminal.trace.scroll` and `terminal.trace.control` probe logging plus extra `terminal.core` scroll info/stdout spam from core scrolling/control handlers, reducing hot-path logging residue from the rain investigation.
  - 2026-03-09: fifth slice landed on feature-branch work: demoted `terminal.sgr` per-sequence logs from `.info` to `.debug` so high-volume SGR traffic no longer pollutes default-info logs.
  - 2026-03-09: sixth slice landed on feature-branch work: demoted high-frequency `terminal.input` send-path logs (`sendKey*`, `sendKeypad*`, `sendChar*`, `sendText`) from `.info` to `.debug` to keep default logs focused on operational signals.
  - 2026-03-09: seventh slice landed on feature-branch work: demoted high-frequency scrollback view-offset logs to `.debug` and removed duplicate stdout emissions in `scrollback_view`, reducing scroll-driven log spam.
  - 2026-03-09: eighth slice landed on feature-branch work: demoted raw CSI-byte tracing in `io_threads.logCsiSequences(...)` from `.info` to `.debug`, keeping the diagnostic path available without polluting default-info output.
  - 2026-03-09: ninth slice landed on feature-branch work: removed duplicate stdout info logs for terminal lifecycle init/resize (`terminal_session`, `resize_reflow`), keeping one structured core log signal per event.

11) Kitty subsystem split
- status: `todo`
- priority: `P2`
- scope:
  - split kitty protocol parse, payload IO/decode, placement/state, and dirty publication responsibilities
  - remove mutation patterns that make delete/update behavior fragile
  - preserve the incremental dirty-publication work already landed
- primary files:
  - `src/terminal/kitty/graphics.zig`

## Recommended Sequencing (2026-03-09)

These can be parallelized in limited lanes, but not as a fully independent rewrite.

Do first:
1) Define the new ownership boundaries on paper.
- Lock down which module owns:
  - runtime IO/threading
  - mode/input publication
  - render publication / presented-generation ack
  - widget presentation only

Then parallelize in bounded lanes:
1) Runtime lane:
- split scheduler/poll ownership out of widget-facing app helpers
- reduce `TerminalWorkspace` to tab ownership + simple polling surface

2) Publication lane:
- narrow `view_cache` into cache publication only
- move dirty-ack / presented-generation lifecycle behind a dedicated publication API

3) UI lane:
- shrink `TerminalWidget` / `terminal_widget_input` into presentation + intent emission only
- remove stale duplicate hover/open APIs once the new boundary is stable

After those land:
1) Input-mode lane:
- replace manual `updateInputSnapshot()` scatter with explicit mode-state publication

2) Protocol lane:
- replace `anytype self` mutation style with a narrow protocol facade

3) Kitty lane:
- split kitty protocol/decode/state/dirty publication once the publication boundary is stable

Unsafe to parallelize immediately:
- `TerminalSession` decomposition, `view_cache` ownership changes, and widget draw lifecycle
  changes all touch the same invariants and should not be rewritten independently without
  a shared contract first.
