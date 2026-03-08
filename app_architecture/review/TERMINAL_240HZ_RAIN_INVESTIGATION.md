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
  - New probe clarification: observed logs came from a single `ascii-rain` instance while only resizing the same window between smaller/larger sizes.

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

## Current Investigation Guard

- Temporary guard has been applied in `src/ui/renderer/gl_backend.zig` to disable self-copy texture shift optimization and force fallback redraw path for validation.
- If artifacts disappear in large Hyprland single-tile layouts, this strongly implicates the shift-copy path as the primary fault surface.
- User validation update (2026-03-08): no visible improvement so far with the guard enabled, so this path is now considered a weaker primary-cause candidate (still possible secondary contributor).

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

## Current Active Guards (2026-03-08)

1. `glCopyTexSubImage2D` self-copy shift disabled
- File: `src/ui/renderer/gl_backend.zig`
- Status: enabled
- Result so far: no meaningful improvement by itself.

2. Force full texture update on output generation/dirty activity (probe)
- File: `src/ui/widgets/terminal_widget_draw.zig`
- Status: enabled (temporary investigation guard)
- Intent: isolate partial dirty-row invalidation path as the cause by bypassing partial texture updates when output is advancing.
- Validation target:
  - If stale/frozen drops disappear, fault is likely in partial update/dirty reconciliation.
  - If issue persists, focus shifts back to redraw scheduling/present cadence rather than partial invalidation correctness.

## Acceptance Criteria for Fix

- At 240Hz, `ascii-rain` no longer shows perceptible frozen subsets under normal runtime load.
- No regressions at 60Hz.
- Terminal redraw metrics show continuous draw progression during sustained output.
- No new tearing/blank-row artifacts introduced by any texture update path change.
