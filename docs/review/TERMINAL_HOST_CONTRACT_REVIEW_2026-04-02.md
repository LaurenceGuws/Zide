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

### 2. Workspace is now the strongest remaining aggregate center

`workspace.zig` now looks more honest than before, but it is still the most
powerful aggregate in the native host path:

- tab ownership
- active-session routing
- poll budgeting
- host-facing active frame state
- tab sync and close-confirm context

This may be correct in part.
It may also still be the place where multiple host concerns get normalized into
one center by convenience rather than by a sharp host contract.

Current live shape:

- session creation and ownership
- active-session routing
- host metadata and sync packaging
- close-confirm policy
- poll budgeting and counters
- host-facing frame-state forwarding

That is enough responsibility concentration that it now reads like the
strongest remaining native-host center-of-gravity candidate.

Current judgment:

- if there is a next terminal-host architecture review, workspace is the
  strongest candidate
- the next question is not “can we delete another publication helper?”
- the next question is “which of these host responsibilities truly belong on
  the workspace aggregate?”

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

Current live shape:

- `visible_terminal_frame.zig` owns visible-terminal gating plus input-phase
  orchestration
- `visible_terminal_frame_hooks_runtime.zig` owns hook routing and terminal
  runtime-state threading for poll/input/scrollbar hooks
- `terminal_draw_surface_runtime.zig` owns draw clipping, progress/scrollbar
  drawing, and widget presentation staging

This is cleaner than before, but it still reads like three adjacent host
orchestration slices rather than one obviously dominant native-terminal host
layer.

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

## Current Ranking

1. `workspace.zig` as native host aggregate center
2. native draw/runtime orchestration split across `visible_terminal_frame*`
   plus `terminal_draw_surface_runtime.zig`
3. publication/frame pacing seam, now mostly flattened and no longer the top
   issue

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

1. Which responsibilities on `workspace.zig` are true workspace concerns, and
   which are just the next host/runtime convenience pile?
2. Should visible-terminal poll/input/draw orchestration read as one explicit
   host layer instead of three adjacent files?
3. If we compare the whole native host path to the Ghostty surface/termio
   split, what still looks second-rate at first glance?

## Bottom Line

The publication contract work did its job.

The next best move is not more tiny publication cleanup.
The next best move is a broader native terminal host review focused on:

- workspace as aggregate center
- draw/runtime orchestration as host center

## Follow-Through

First real host-aggregate cut landed:

- active-session cwd copy
- active-session child-exit refresh and liveness
- active-session close-confirm requirement
- close-confirm tab scan and context lookup
- tab sync packaging

These no longer live on `workspace.zig`; they now live under
`src/terminal/core/workspace_host.zig`.

That leaves `workspace.zig` reading closer to its real center:

- tab ownership and activation
- sizing and tab lifecycle
- poll budgeting and counters
- frame-state forwarding
- host-specific packaging and close-confirm types no longer declared there

Current rerank:

1. re-rank whether the remaining workspace surface is now honest enough to
   stop, or whether another real host/runtime convenience slab still hides
   there
2. native draw/runtime orchestration split across `visible_terminal_frame*`
   and `terminal_draw_surface_runtime.zig`
3. publication micro-cuts, still paused unless a larger seam appears

Visible-frame follow-through also started:

- `visible_terminal_frame_hooks_runtime.handle(...)` no longer carries
  tab-bar sync as part of its hook contract
- callers now do that post-step themselves
- the extra single-caller shell `visible_terminal_frame.zig` is now gone;
  poll/input routing lives directly in
  `visible_terminal_frame_hooks_runtime.zig`

That makes the visible-frame hook layer read slightly more like a true
poll/input routing owner and less like a mixed terminal UI convenience center.

Another post-present ownership cut landed too:

- terminal presentation-feedback flush no longer lives under
  `terminal_draw_surface_runtime.zig`
- that post-submission action now lives in `present_feedback_runtime.zig`

That keeps the draw-surface lane closer to actual draw responsibility and keeps
post-present cleanup with the present-completion owner.

## Rerank Point

After the workspace-host cuts plus the visible-frame collapse, this lane is
now close to diminishing returns.

Current read from the live code:

- `workspace.zig` now reads much closer to an honest tab/poll aggregate
- `workspace_host.zig` carries the active-session host convenience that did not
  belong on the main aggregate
- `visible_terminal_frame_hooks_runtime.zig` now reads as the actual
  poll/input routing owner for visible terminal interaction
- `terminal_draw_surface_runtime.zig` is narrower and more draw-shaped after
  losing post-present feedback flush

That means the old question:

- "is there still an obvious fake host center in the native terminal path?"

now has a weaker answer than it did at the start of this review.

Current judgment:

1. pause this exact host-aggregation lane unless a new large false center
   appears
2. if terminal architecture work continues, the next step should come from a
   broader top-level rerank against engine/publication/native-host clarity,
   not from more local host cleanup by momentum
3. compare the whole terminal host path to the strongest references again
   before opening the next kill-order
