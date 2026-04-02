# Terminal Host Contract Review 2026-04-02

## Purpose

Re-review the full native terminal host path after the publication contract
cleanup wave.

This review supersedes the narrower question of whether frame pacing or
widget/publication micro-seams still need cleanup by default.

## Scope

Live code reviewed:

- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_polling.zig`
- `src/app/terminal/terminal_poll_runtime.zig`
- `src/app/terminal/terminal_frame_pacing_runtime.zig`
- `src/app/frame_render_idle_runtime.zig`
- `src/app/terminal/terminal_draw_surface_runtime.zig`
- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`

Reference pressure:

- `dev_references/terminals/ghostty/src/termio/Options.zig`
- `dev_references/terminals/ghostty/src/termio/Termio.zig`
- `dev_references/terminals/ghostty/src/Surface.zig`
- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`

## Current State

The recent publication-contract work materially improved the host path:

- publication owns the host-facing frame snapshot shape
- workspace forwards that active-session snapshot
- poll runtime asks publication whether published generation changed
- frame pacing consumes the publication-owned frame snapshot directly
- widget handoff prep and submission retirement policy both moved under the
  publication owner

That means the old problem statement is stale.

The native host path no longer primarily suffers from scattered publication
helper duplication.

## Current Read

The terminal host path now reads as three mostly honest layers:

1. publication and workspace expose host-facing terminal state
2. frame/poll runtime use that state to decide wake/sleep/redraw
3. widget draw consumes publication snapshots and maintains local retained
   texture/render state

This is much better than before.

The remaining architectural question is broader:

- does the native terminal host now read like one clear host over one engine
  truth, or do we still have a larger center-of-gravity problem elsewhere in
  the host path?

## Findings

### 1. Publication-frame contract is no longer the dominant problem

Why:

- the strongest duplication is already gone
- the remaining widget-local presentation state looks justified by the retained
  texture path
- pacing and poll now read through owner-shaped publication/workspace state

Current judgment:

- this lane should pause by default
- continue only if a new large contract split appears

### 2. Workspace still deserves scrutiny as the native host aggregate

`workspace.zig` now looks more honest than before, but it is still a powerful
aggregate in the native host path:

- tab ownership
- active-session routing
- poll budgeting
- host-facing active frame state
- tab sync and close-confirm context

This may be correct.
It may also still be the place where multiple host concerns get normalized into
one center by convenience.

Current judgment:

- if there is a next terminal-host architecture review, workspace is a stronger
  candidate than the publication/frame-pacing seam we just finished flattening

### 3. Native terminal draw/runtime split is much better, but still the other likely host pressure point

`terminal_draw_surface_runtime.zig`, `frame_render_idle_runtime.zig`, and
`visible_terminal_frame_hooks_runtime.zig` are cleaner now, but together they
still define much of the native host orchestration shape:

- visibility gating
- poll/wake routing
- draw submission
- redraw scheduling
- terminal-specific runtime hooks

This is not obviously wrong.
But it is the other place where the host path could still hide a higher-level
fake center after publication cleanup.

## Comparison Pressure

From Ghostty:

- `termio` owns IO/runtime state and speaks to renderer/surface through explicit
  handles
- `Surface` reads like a host surface over that engine/runtime pair, not like a
  pile of adjacent summaries that all feel equally authoritative

Zide is closer to that now than it was before.

The remaining gap is no longer “publication helper sprawl.”
The remaining gap is whether the native host as a whole has one sufficiently
obvious aggregate center and one sufficiently obvious engine/publication truth
under it.

## Recommended Next Battlefield

The next strongest architectural review target is:

- native host aggregation centered on `workspace.zig` plus the draw/runtime
  orchestration path

Why this beats more publication micro-cuts:

- publication/frame pacing is now close to diminishing returns
- widget-local presentation state now looks mostly honest
- the next real question is whether the native host path still has a broader
  center-of-gravity problem above those cleaner contracts

## Recommended Next Questions

1. Is `workspace.zig` now the correct long-term host aggregate, or is it still
   absorbing unrelated host/runtime responsibilities?
2. Do the native draw/runtime files read like one clean host orchestration
   layer, or like multiple adjacent partial owners?
3. If we compare the whole native host path to the Ghostty surface/termio
   split, what is still structurally second-rate at first glance?

## Bottom Line

The publication contract work did its job.

The next best move is not more tiny publication cleanup.
The next best move is a broader native terminal host review focused on:

- workspace as aggregate center
- draw/runtime orchestration as host center
