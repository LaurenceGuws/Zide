# Terminal Rain Rendering Investigation (2026-03-08)

## Scope

Investigate why `ascii-rain-git` shows intermittent "standing still" drops in some layouts. Initial assumption was "240Hz-only", but updated reproduction indicates the stronger trigger is large single-tile Hyprland layouts (also reproducible on 60Hz at 4k).

This note documents:
- what was observed and compared
- what was ruled out
- the most likely fault surfaces
- concrete next validation steps

This doc is the detailed source of truth for the current focus item.

## Reproduction Baseline

- Reproducer command:
  - `yay -Qi ascii-rain-git` confirms package metadata
  - run `ascii-rain` in terminal pane
- Updated user observation:
  - Not strictly tied to 240Hz.
  - Reproduces when terminal occupies a large single-tile workspace on Hyprland.
  - Can reproduce on 60Hz at 4k in that large-tile layout.
  - New probe clarification: observed logs came from a single `ascii-rain` instance.
  - Correction: this is not primarily a resize-event trigger. Launching directly in large full-tile state reproduces; launching in half-tile state often does not.

## Key Differential: Kitty vs Zide

Kitty source inspected under:
- `reference_repos/terminals/kitty/kitty/*`
- `reference_repos/terminals/kitty/glfw/*`

### What Kitty Does (Relevant)

1. No explicit "240Hz mode"
- It still relies on standard sync/present behavior (`glfwSwapInterval`) and configurable `sync_to_monitor`.
- Files:
  - `reference_repos/terminals/kitty/kitty/glfw.c` (`apply_swap_interval`)
  - `reference_repos/terminals/kitty/kitty/options/definition.py` (`sync_to_monitor`, `repaint_delay`, `input_delay`)

2. Explicit frame callback request/recovery path (Wayland/macOS)
- Uses render-frame requests and tracks render-frame readiness.
- Re-requests frame if one does not arrive within 250ms.
- Files:
  - `reference_repos/terminals/kitty/kitty/glfw.c` (`request_frame_render`, frame callbacks)
  - `reference_repos/terminals/kitty/kitty/child-monitor.c` (`no_render_frame_received_recently`, `render_os_window`)

3. Render pacing separated from input pacing
- `repaint_delay` and `input_delay` are independent.
- Repaint delay is ignored when pending input exists.
- Files:
  - `reference_repos/terminals/kitty/kitty/options/definition.py`
  - `reference_repos/terminals/kitty/kitty/child-monitor.c` (main/render loop + IO wakeup path)

4. Authoritative dirty-line driven GPU updates
- GPU cell data path updates from line dirty state and marks lines clean post-render.
- Files:
  - `reference_repos/terminals/kitty/kitty/screen.c` (`screen_update_cell_data`)
  - `reference_repos/terminals/kitty/kitty/shaders.c` (`send_cell_data_to_gpu`)

### What Zide Currently Does (Relevant)

1. Poll/redraw gating and idle backoff
- Terminal redraw typically depends on poll path signaling (`hasData`/`poll`) and setting `needs_redraw`.
- Files:
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
  - `src/app/visible_terminal_frame_hooks_runtime.zig`
  - `src/app/frame_render_idle_runtime.zig`

2. Partial texture update + viewport texture shift path
- Uses `scrollTerminalTexture(...)` + partial row redraw for certain generation/shift conditions.
- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/terminal/core/view_cache.zig`
  - `src/ui/renderer/gl_backend.zig`

3. Existing instrumentation is draw/poll-centric
- `input.latency`, `terminal.ui.perf`, and poll metrics exist.
- A temporary branch-local starvation logger was added in `frame_render_idle_runtime.zig` to detect prolonged terminal output pressure while no redraw occurs.

## What Is Unlikely

Pure PTY throughput limitation as the primary cause is unlikely:
- Same workload renders smoothly in Kitty at high refresh.
- Existing Zide issue signature is selective visual stall (subset appears frozen), which better matches redraw/damage scheduling behavior than total throughput saturation.

## Working Hypotheses (Ranked)

1. Redraw scheduling starvation under high-refresh cadence
- Terminal output exists, but redraw trigger or cadence occasionally fails to keep texture updates continuous.
- Symptom fit: visible pauses with later catch-up.

2. Partial texture update correctness issue under viewport-shift path
- `scrollTerminalTexture` reuse + dirty rows/columns reconciliation may occasionally preserve stale regions under high-frequency incremental updates.
- Symptom fit: only some rain drops appear to stand still.
- Additional risk signal:
  - The shift path currently uses `glCopyTexSubImage2D` self-copy in the same render target, which is likely driver/compositor sensitive at large target sizes.

3. Poll budget/cadence interaction with active-output pressure
- Current budget model may be correct at 60Hz but can produce perceptible jitter at 240Hz due to timing granularity/cadence mismatch.

## Why Kitty Matters Here

Kitty demonstrates three robustness properties we should mirror:

1. Frame-request watchdog/recovery
- If compositor/frame callback flow stalls, force re-request quickly.

2. Input/read and repaint pacing are explicitly separated
- Prevents one cadence from accidentally starving the other.

3. Dirty source of truth is conservative and authoritative
- Reduced dependence on cache-shift correctness for visible output continuity.

## Immediate Validation Plan

1. Add a temporary kill-switch for viewport texture shift optimization
- Force full or non-shift partial path while keeping other logic unchanged.
- Compare artifact frequency at 240Hz.

2. Add redraw watchdog in Zide frame loop
- If terminal output pressure persists without redraw beyond threshold, force redraw request and log event.

3. Compare metrics under 60Hz vs 240Hz with identical workload
- Track:
  - poll sequence progression
  - draw sequence progression
  - prolonged output pressure without redraw
  - partial/full texture update ratios

4. Keep changes small and bisectable
- Separate "instrumentation only" commits from behavior changes.

## Additional Probe Findings (2026-03-08)

- While probing, `terminal.parse` emitted repeated `parse wait timedWait failed err=Timeout` warnings.
- In this parse-thread loop, timeout is expected behavior for bounded wait cadence and should not be logged as warning.
- Patch applied:
  - `src/terminal/core/io_threads.zig`
  - suppress warning for `error.Timeout`; keep warning for non-timeout wait failures.
- Rationale:
  - avoids log-noise-induced observer effect during perf/render investigations
  - keeps signal for actual synchronization errors

- The noisy timeout logs were produced during a single-process resize probe (not multi-instance stress), which further weakens "raw throughput saturation" as the primary explanation.

## Current Instrumentation Probe (2026-03-08)

Runtime-only instrumentation has been added (no behavior/path forcing):

1. `terminal.ui.statebug` draw-state snapshots
- Files:
  - `src/ui/widgets/terminal_widget.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Emits every ~100ms:
  - draw gap (`draw_gap_ms`), draw duration, generation/gen-delta
  - dirty/damage spans, full/partial choice, clear result
  - terminal geometry (`rows`, `cols`, `widget_px`, `tex_px`, `scale`)

2. `terminal.ui.statebug` idle pressure snapshots
- File: `src/app/frame_render_idle_runtime.zig`
- Emits when terminal output pressure persists while no redraw occurs:
  - pressure time, idle frames, redraw flag, draw/poll sequence IDs, window pixel size

3. Poll-path probe around `hasData`/generation
- File: `src/app/poll_visible_terminal_sessions_runtime.zig`
- Emits every ~100ms:
  - `hasData` pre/post poll, generation pre/post poll, and whether poll path reported activity
- Purpose:
  - validate suspected false-negative window where `output_pending` is cleared/observed low and UI chooses longer idle sleeps while generation is still advancing.

4. Full-dirty attribution probe (new)
- Files:
  - `src/terminal/model/screen/grid.zig`
  - `src/terminal/model/screen/screen.zig`
  - `src/terminal/core/render_cache.zig`
  - `src/terminal/core/view_cache.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Added `FullDirtyReason` + `full_dirty_seq` tracking at the grid source of truth.
- Wired reason + sequence through snapshot/view-cache into draw logs.
- `terminal.ui.perf` and `terminal.ui.statebug` now emit:
  - `full_dirty_reason=<enum>`
  - `full_dirty_seq=<u64>`
- Explicit reason callsites now include:
  - alt-screen enter/exit
  - sync-updates disable path
  - DECSTR soft reset
  - scrollback offset/view movement
  - resize reflow
  - kitty image/placement mutations
  - screen clear/reverse/palette full clears

4. Logging scope
- `.zide.lua` configured to low-noise bug-scoped tags:
  - `terminal.ui.statebug,terminal.ui.perf,input.latency,terminal.core`

## Confirmed Signal (2026-03-08, latest logs)

- `poll_probe` repeatedly showed `hasData_pre=0/hasData_post=0` windows while generation later jumped significantly on subsequent draws.
- `idle_backoff_after_gen_advance` fired with `sleep_ms=0.033` and `gen_advance_ms~145ms`, confirming idle backoff can still trigger shortly after output generation movement when `hasData` is low.
This confirms a practical scheduler race window around `hasData` gating and idle sleep selection.
- A stronger rendering signal emerged from later traces:
  - in the problematic large-tile case, `terminal.ui.perf` spends long stretches with `dirty=full` and `full_reasons ... dirty_full=1`
  - this keeps Zide on full-surface redraws instead of the viewport-shift / partial-damage fast path
  - the cost increase scales directly with terminal width, matching the “full tile bad, half tile okay” symptom much better than the `poll_probe` log rate itself
- With full-dirty attribution, the next narrowing step is to identify which `full_dirty_reason` dominates during `ascii-rain` stalls in the large-tile case and then target that producer path directly.
- Follow-up fix:
  - `view_cache` forced-full path now emits explicit `full_dirty_reason` attribution instead of inheriting ambiguous/empty source reason.
  - This prevents persistent `full_dirty_reason=unknown full_dirty_seq=0` during large-tile forced redraw episodes and allows direct ranking of full-dirty producers.
- Applied narrowing:
  - full-region scroll output no longer bumps `clear_generation`
  - `view_cache` therefore stops escalating normal live-bottom scroll churn into `view_cache_clear_generation_change` full redraws
  - added a session regression that asserts a bottom-following scroll publishes `dirty=partial` with `viewport_shift_rows=1`
  - removed the no-thread `feedOutputBytes(...)` blanket full-damage request so direct parser feeds now respect incremental screen dirty tracking

## Applied Fix Candidate (2026-03-08)

- File: `src/app/frame_render_idle_runtime.zig`
- Change:
  - keep low-latency idle sleep (`1ms`) not only when `hasData` is true, but also for a short grace window (250ms) after generation advances.
- Intent:
  - prevent 33ms/100ms backoff from engaging during brief `hasData=0` gaps while output is still actively progressing.

## Applied Contract Fix (2026-03-08)

- Files:
  - `src/terminal/core/view_cache.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/ui/widgets/terminal_widget.zig`
  - `src/app/post_preinput_hooks_runtime.zig`
- Change:
  - make pending scroll/view-cache refresh consumption explicit: successful `updateViewCacheForScroll*` calls now clear `view_cache_pending`
  - service pending view-cache refreshes under the draw snapshot lock before copying the published render cache
  - stop app/widget lock-free reads of `TerminalSession.renderCache()` for cursor blink/arming paths; use widget-owned snapshot state instead
- Intent:
  - remove stale-cache reads from the UI/backend seam
  - restore a single authoritative point where pending scroll/view selection state is folded into the render cache before draw
  - reduce dependence on best-effort `tryLock` refreshes for visible correctness

## Applied Input Contract Fix (2026-03-08)

- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/protocol/csi.zig`
  - `src/ui/widgets/terminal_widget_input.zig`
  - `src/ui/widgets/terminal_widget_hover.zig`
  - `src/ui/widgets/terminal_widget_open.zig`
- Change:
  - expanded `TerminalSession.input_snapshot` so UI/input code reads bracketed paste, auto-repeat, alternate-scroll, alt-screen state, and live screen dimensions atomically
  - refresh that snapshot on CSI mode changes and alt-screen enter/exit
  - move hover hit-testing, ctrl+click open, and selection hit-mapping onto the widget-owned published draw cache instead of live session snapshot reads
  - keep the truly stateful paths under the session mutex: OSC clipboard pickup, selection/scroll mutations, middle-click paste emission, and terminal mouse-reporting bookkeeping
- Intent:
  - remove the previous mixed contract where `terminal_widget_input` could skip the lock but still touch non-thread-safe session state
  - make the UI/backend seam explicit: published draw cache + atomic input snapshot for reads, short locked sections for mutations and input-state bookkeeping

## Applied Redraw Authority Fix (2026-03-08)

- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
  - `src/app/frame_render_idle_runtime.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - added `TerminalSession.publishedGeneration()` to expose the generation of the currently published render cache
  - visible-terminal polling now requests redraw from active-session published-generation changes instead of raw `any_polled` / `hasData()` activity
  - frame idle runtime now tracks observed vs drawn published generation and forces redraw when a newer published cache exists
  - draw latency metrics now publish the rendered cache generation so frame scheduling can track what was actually presented
- Intent:
  - separate poll pressure from redraw authority
  - make frame presentation follow cache publication, not `output_pending` timing windows

## Applied Texture-Shift Kill-Switch (2026-03-08)

- Files:
  - `src/ui/renderer.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/config/lua_config_iface.zig`
  - `src/config/lua_config_shared.zig`
  - `src/config/lua_config_ziglua_parse.zig`
  - `src/app/init_runtime.zig`
  - `src/app/reload_config_runtime.zig`
  - `assets/config/init.lua`
- Change:
  - added reloadable `terminal.texture_shift` config, default `true`
  - gated the `scrollTerminalTexture(...)` viewport-shift optimization on that renderer flag
  - disabling the flag leaves the existing full redraw fallback intact
- Intent:
  - allow direct A/B validation of the suspected `glCopyTexSubImage2D` self-copy path without flattening the rest of terminal redraw behavior

## Applied Texture-Shift Coverage (2026-03-08)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/tests_main.zig`
- Change:
  - extracted the viewport texture-shift gate into a pure planning helper
  - added unit coverage for:
    - fast-path eligible shift attempts
    - `terminal.texture_shift = false` forcing full redraw fallback
    - oversize viewport shifts forcing full redraw fallback
    - already-forced-full draws refusing the shift path
    - scrollback-view movement refusing the shift path
- Intent:
  - make the kill-switch behavior regression-testable so enabled vs disabled path selection is not only a manual probe

## Applied Poll Backlog Hint Fix (2026-03-08)

- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/workspace.zig`
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
- Change:
  - added explicit published-generation backlog helpers on `TerminalSession`
  - workspace `active_spillover_hint` now treats backlog as either PTY-ready data or unpublished-generation work, instead of consulting `hasData()` alone
  - poll probe logging now emits both `currentGeneration` and published cache generation before/after polling
- Intent:
  - keep poll scheduling conservative while making poll metrics and diagnostics reflect the real two-stage pipeline (PTY readiness plus parse/cache publication backlog)

## Acceptance Criteria for Fix

- At 240Hz, `ascii-rain` no longer shows perceptible frozen subsets under normal runtime load.
- No regressions at 60Hz.
- Terminal redraw metrics show continuous draw progression during sustained output.
- No new tearing/blank-row artifacts introduced by any texture update path change.
