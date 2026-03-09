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
  - later traces showed top rows are not universally omitted from partial damage; the more stable remaining fault is `~120ms` draw cadence with large generation jumps between frames
  - patched `frame_render_idle_runtime` so `currentGeneration != publishedGeneration` counts as active terminal pressure, preventing long idle sleeps while parse-thread backlog is still waiting to publish
  - added temporary `cache_refine` tracing in `view_cache` to compare source dirty spans against post-hash dirty spans on the next run
  - the next repro showed the row-hash refinement step collapsing `src_damage_rows=0..N` into bottom-heavy `resolved_damage_rows=M..N` before draw; the comparison base was the newest published cache, not the cache generation actually presented on screen
  - patched the seam so row-hash refinement only runs when the active published cache generation matches a new `presented_generation` marker updated by `terminal_widget_draw` after the texture upload completes
  - added a regression that simulates repeated scroll publications without an intervening presentation and asserts top-row damage is preserved instead of being refined away
  - latest full-screen rain repro now keeps refinement aligned (`refine_base_gen == presented_gen`) and the user reported the result as the best state so far, with full-screen rain nearly perfect
  - removed temporary `cache_refine`/row-sample probe logging from the hot path and dropped the stale `generation changed + dirty=none => force full redraw` fallback, since the render-cache contract now distinguishes published vs presented generations explicitly
  - `view_cache` now tracks `visible_history_generation` for scrolled primary-screen views, so visible scrollback/history mutations are diffed against the last presented cache instead of relying on generic `force_full_damage` escape hatches
  - when no presented diff base exists for a visible-history change, `view_cache` now attributes that fallback explicitly as `view_cache_history_generation_change` instead of collapsing into an ambiguous force-full path
  - same-generation cursor-style changes are now treated as overlay-facing cache state; config reload no longer forces a full terminal texture invalidate just to publish a new cursor shape/blink mode
  - removed redundant `requestForceFullDamage(...)` usage for default-color changes, ANSI palette setup/remap, and 132-column mode; those paths now rely on screen-model full dirty, visible-history cache diffing, or clear-generation publication instead of a second session-side invalidate flag
  - removed the remaining conservative `ED 0/1 => force_full_damage` fallback; partial erase-display variants now rely on the screen model’s published dirty ranges directly, and the dead `force_full_ed` investigation bookkeeping was deleted with it
  - after removing the last callers, the `force_full_damage` session-side invalidation flag and the `view_cache_force_full_damage` fallback reason were deleted entirely; full redraw authority now comes from published cache/model state instead of an unused side-channel
  - scrollback-view movement is no longer published as a screen-model full dirty event; `view_cache` now distinguishes pure viewport remaps and publishes `viewport_shift_exposed_only` partial damage, so draw can use the texture-shift fast path for scrolled history and only fall back to full when that copy path is unavailable
  - disabling synchronized updates no longer synthesizes a full-screen dirty event on its own; the renderer already freezes presentation while sync mode is active, so disable now publishes the accumulated real screen damage (`none` or partial/full as already tracked) instead of forcing `sync_updates_disabled` full redraws every frame batch
  - kitty/image redraw policy is now narrower on the renderer side: partial redraw no longer escalates to full just because kitty content exists somewhere in the viewport; full redraw is now reserved for actual dirty/blink overlap with visible placements, while static or non-overlapping kitty content stays on the normal partial path

## Applied Fix Candidate (2026-03-09)

- File: `src/app/frame_render_idle_runtime.zig`
- Change:
  - keep low-latency idle sleep (`1ms`) not only when `hasData` is true, but also for a short grace window (250ms) after generation advances.
- Intent:
  - prevent 33ms/100ms backoff from engaging during brief `hasData=0` gaps while output is still actively progressing.

## Applied Contract Fix (2026-03-09)

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

## Applied Input Contract Fix (2026-03-09)

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

## Applied Redraw Authority Fix (2026-03-09)

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

## Applied Presented-Generation Refinement Fix (2026-03-09)

- Files:
  - `src/terminal/core/terminal_session.zig`
  - `src/terminal/core/view_cache.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - added `TerminalSession.presentedGeneration()` and `notePresentedGeneration(...)` so the backend can distinguish the latest published render cache from the last cache generation actually uploaded to the terminal texture
  - `terminal_widget_draw` now marks the cache generation as presented only after the offscreen terminal texture update completes
  - `view_cache` row-hash refinement is now gated on `active_cache.generation == presented_generation`; if draw is behind publication, refinement falls back to the source dirty rows instead of diffing against an unseen cache
  - `cache_refine` tracing now logs `refine_base_gen` and `presented_gen` to make this seam visible in future repros
  - added a terminal-session regression covering repeated scroll publications without an intervening draw
- Intent:
  - stop partial-damage refinement from assuming intermediate published generations have already reached the screen
  - preserve top-row damage during multi-generation bursts, which matches the user-visible “row 1 is laziest, bottom rows catch up first” symptom

## Cleanup Pass (2026-03-09)

- Files:
  - `src/terminal/core/view_cache.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - removed temporary `cache_refine` tracing and per-row sample probe logging used to isolate the refinement seam
  - removed the draw-path fallback that forced a full texture redraw whenever cache generation advanced with `dirty == .none`
  - kept the structural fixes: presented-generation tracking, full-dirty attribution, and normal perf logging
- Intent:
  - reduce investigation-only hot-path noise
  - stop carrying obsolete redraw fallbacks once the cache publication/presentation contract is explicit

## Scrolled-Viewport Partial Cleanup (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - replaced the ad-hoc draw-path `scroll_offset > 0 => full redraw` policy with an explicit texture update plan helper
  - partial texture updates are now allowed while scrolled, as long as the render cache itself reports partial damage and no real full-redraw condition is active
  - viewport texture shift remains disabled while scrolled; only the unrelated blanket full-redraw fallback was removed
  - added unit coverage proving that scrolled partial damage remains eligible for partial texture upload, while non-ready textures still force a full upload
- Intent:
  - keep draw policy aligned with cache authority
  - remove another broad fallback that penalized correctness-preserving scrollback views without improving the underlying contract

## Investigation Probe Retirement (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
  - `src/app/poll_visible_terminal_sessions_runtime.zig`
  - `src/app/frame_render_idle_runtime.zig`
- Change:
  - removed temporary `terminal.ui.statebug` probe state and log emission from draw, poll, and idle scheduling paths
  - removed widget-side state used only to compute draw-gap/generation probe logs
  - kept the underlying redraw and backlog behavior changes; only the investigation scaffolding was retired
- Intent:
  - return the hot paths to production-oriented code after the investigation converged
  - reduce per-frame/per-poll bookkeeping that no longer contributes to terminal correctness

## Cache-Authority Scroll Cleanup (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget.zig`
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - removed widget-local scroll-history tracking used only to force a redraw policy decision in draw
  - `chooseTextureUpdatePlan(...)` no longer treats a widget-observed scroll-offset change as its own full-redraw reason
  - draw now relies on the published render cache for scroll/viewport correctness, while renderer-local reasons (texture recreation, cell metrics, scale, kitty images, blink phase) still remain local
- Intent:
  - keep redraw authority centered on published cache state instead of duplicating scroll-change policy in widget state
  - shrink one more UI/backend seam where local widget history could override backend damage truth

## Cache-Authority Alt-State Cleanup (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - removed draw-local alt-screen transition forcing from the texture update plan
  - widget still tracks `alt_exit` timing for diagnostics, but alt-screen redraw policy now comes from the published render cache (`cache.dirty`, `cache.alt_active`, and full-dirty reason) rather than a second widget-side reason bit
- Intent:
  - keep renderer decisions focused on renderer-local constraints
  - avoid duplicating backend state-transition policy in the widget once the cache publication contract is explicit

## Viewport-Shift Fallback Cleanup (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - removed the viewport-shift policy that escalated to a full redraw whenever the texture-copy fast path was unavailable
  - draw now attempts the texture shift when eligible; otherwise it falls back to the normal published-damage path instead of forcing a full upload
  - updated unit coverage so shift-disabled, oversize-shift, and already-full cases all resolve to the standard damage path rather than a synthetic full redraw
- Intent:
  - decouple the optional texture-copy optimization from correctness policy
  - preserve correctness through published damage first, using the shift path only as a performance optimization

## Kitty Full-Redraw Narrowing (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - narrowed kitty-triggered full redraws from “kitty content exists” to “kitty content exists and there is cell damage that needs reconciliation in the texture”
  - static kitty content no longer forces a full texture update by itself when the cache is otherwise clean
  - added draw-path unit coverage for the static-kitty-clean case and the kitty-plus-dirty case
- Intent:
  - reduce one more unconditional renderer-side full-redraw reason
  - keep kitty generation changes authoritative while avoiding extra work for unchanged kitty scenes

## Blink Partial-Damage Cleanup (2026-03-09)

- Files:
  - `src/ui/widgets/terminal_widget_draw.zig`
- Change:
  - blink phase changes no longer count as an unconditional full-redraw reason in the texture update plan
  - blink-only updates now enter the existing partial redraw path, with blink rows added explicitly to the partial row/column plan
  - kitty overlap remains conservative: if kitty content exists and blink work must be reconciled, the path still upgrades to full until finer overlap metadata exists
  - added unit coverage proving that blink-only changes request partial redraw work instead of a full upload
- Intent:
  - turn another broad renderer-side redraw policy into explicit partial work
  - keep correctness while moving the renderer closer to a damage-driven model

## Sync-Updates Force-Full Cleanup (2026-03-09)

- Files:
  - `src/terminal/core/terminal_session.zig`
- Change:
  - removed the redundant `requestForceFullDamage("sync updates mode changed")` path from `setSyncUpdates(...)`
  - initial narrowing removed the extra session-side force-full path while still leaving disable on the screen-model full-dirty publication
  - enabling sync updates no longer synthesizes redraw work when the screen is otherwise clean
  - later follow-up removed that remaining full-dirty publication too: sync disable now publishes the already-buffered real damage (`none` or partial/full) instead of forcing a full redraw reason
  - removed the now-dead sync-disable pattern-stat path and updated tests to cover clean disable and buffered-partial disable behavior
- Intent:
  - keep redraw authority in published backend damage state rather than in extra “force full” escape hatches
  - narrow one more backend-side quick fix that outlived the original investigation

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
