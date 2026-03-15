# Wayland Present Rollout Notes (2026-03)

This file holds the landed rollout/status notes that previously lived inline in
`docs/todo/terminal/wayland_present.md`.

Use it for:
- phase-by-phase landed-shape notes
- present-path cutover history
- removed experiment/debug-path cleanup notes

Use `docs/todo/terminal/wayland_present.md` for the current ownership model,
validation semantics, sequencing risks, and exit criteria.

## Phase 1 Landed Shape

- renderer owns explicit scene-target state plus contract snapshotting for:
  - logical size
  - drawable size
  - display index
  - render scale
- those boundaries invalidate/destroy stale scene-target state without reviving
  direct-default ownership
- scene-target create/recreate/clear happens during frame startup while keeping
  the renderer-owned target lifecycle explicit

## Phase 2 Landed Shape

- `beginFrame()` composes into the renderer-owned scene target when available
- `endFrame()` performs one explicit scene-to-default draw before swap
- widget-local retained targets remain unchanged
- terminal/editor subpasses restore to the active main composition target
- the final scene-to-default draw overwrites rather than blends into the
  default framebuffer
- special glyph and shaded-block follow-up fixes are on the landed scene-target
  path, not on a revived direct-default path

## Phase 3 Current Status At Cutover

- first Phase 3 slice is now landed in the app/runtime path
- terminal draw no longer retires presentation feedback immediately after
  widget draw
- terminal presentation feedback is now staged during
  `terminal_draw_surface_runtime.draw(...)` and flushed only after
  `shell.endFrame()`
- that means terminal presented-generation retirement now crosses the
  renderer-owned scene submission boundary instead of hanging directly off
  widget-local draw completion
- renderer swap success/failure now also participates in that boundary:
  `Renderer.endFrame()` returns explicit submission success, and terminal
  presentation feedback is only flushed on successful submission instead of
  unconditionally after `endFrame()`
- that boundary is now tighter again: renderer submission now carries an
  explicit monotonic submission sequence, `Shell.endFrame()` returns that
  renderer-owned submission result, and terminal presentation feedback records
  the last successful terminal submission sequence instead of relying on a
  naked success boolean alone
- the old renderer-local `endFrame() -> bool` seam is now gone too:
  submission is owned directly by `Renderer.submitFrame()`, so Phase 3 no
  longer straddles both a legacy boolean swap path and the newer
  renderer-owned submission identity
- the next Phase 3 slice, if still needed, should build on that explicit
  renderer-owned submission sequence rather than widening app/widget-local
  present ownership again

## Phase 4 Current Status At Cutover

- first Phase 4 slice is now landed in `src/ui/renderer.zig`
- frame startup no longer treats the default framebuffer as a valid normal
  main composition target
- the active main path is now:
  - begin the frame in the renderer-owned scene target
  - restore terminal/editor subpasses back into that same scene target
  - do one final scene-to-default present draw before swap
- the default framebuffer remains only as an explicit degraded fallback when
  scene-target activation fails during frame startup or subpass restoration; it
  is no longer the architectural alternative main path
- the old swap-edge experiment matrix is no longer part of the live renderer
  surface:
  - removed: `copy_back_to_front`, `finish_before_swap`,
    `finish_before_and_after_swap`, cap/recovery/every-frame experiment modes,
    and the old `pre_fallback_front` probe path
  - kept: `swap_interval_0` plus the recent-input publication-window A/B
    overrides that still map to the current scene-owned mitigation path
- post-beta cleanup has now removed the remaining heavyweight
  `terminal.ui.target_sample` readback path from the live renderer/runtime
  surface
- row-render logs remain available for lightweight row stats, but suspicious
  present readback is no longer carried as normal runtime code until a new
  issue proves it is worth reintroducing in a cheaper form

## First Implementation Slice

The first code slice was:

- introduce renderer-owned scene-target lifecycle and invalidation bookkeeping
- do not change the active main composition path yet
- keep the slice renderer-local and behavior-neutral
