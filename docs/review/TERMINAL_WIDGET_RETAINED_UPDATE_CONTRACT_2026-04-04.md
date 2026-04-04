# Terminal Widget Retained Update Contract

Date: 2026-04-04

## Purpose

Record the first explicit contract cut inside the retained-surface update
front.

The problem was not just that retained surface logic lived in the presenter.

The deeper problem was that the presenter still assembled update policy from:

- raw retained-state arrays
- full vs partial update heuristics
- viewport-shift policy
- full-frame fast-path threshold logic
- partial damage-plan assembly

That was still too much implicit policy for one host-side hot path.

## What Changed

Two ownership lines are explicit now.

### 1. `RetainedState` owns partial-plan scratch storage

`src/ui/widgets/terminal_widget_retained_state.zig`
now owns the partial plan scratch contract through:

- `RetainedState.PartialDrawPlan`
- `RetainedState.ensurePartialDrawPlan(...)`

That means resize/logging/fallback for plan scratch no longer lives inline in
the presenter.

### 2. `TerminalSurfacePresenter` owns one retained update plan

`src/ui/widgets/terminal_widget_surface_presenter.zig`
now owns one explicit retained update contract through:

- `RetainedSurfaceGeometry`
- `RetainedSurfaceUpdatePlan`
- `planRetainedSurfaceUpdate(...)`

That contract now groups:

- retained surface geometry
- texture recreation effect
- full vs partial update mode
- viewport-shift attempt/consumption
- full-frame fast-path escalation
- optional partial-plan attachment

The presenter still executes the draw work, but it no longer reconstructs the
update decision from several helper families inline.

### 3. Full and partial retained execution now share one draw-span contract

`src/ui/widgets/terminal_widget_surface_presenter.zig`
now also owns shared retained execution helpers for:

- background-pass row/span traversal
- glyph-pass row/span traversal

That means full and partial retained updates no longer each encode their own
separate row/span iteration logic in the main presentation function.

### 4. Post-update present choreography now uses one present-state contract

`src/ui/widgets/terminal_widget_surface_presenter.zig`
now owns one explicit post-update present state through:

- `RetainedSurfacePresentState`
- `refreshRetainedSurfacePresentState(...)`
- `beginRetainedViewportClip(...)`
- `logRetainedSurfaceUnavailable(...)`
- `presentRetainedSurface(...)`

That contract now groups:

- retained target availability refresh
- retained readiness truth
- viewport-clip application
- unavailable-present logging
- final retained-surface present decision

### 5. Retained content execution now uses one sequencing contract

`src/ui/widgets/terminal_widget_surface_presenter.zig`
now owns one explicit retained content execution contract through:

- `RetainedSurfaceExecutionResult`
- `executeRetainedSurfaceUpdate(...)`

That contract now groups:

- background pass
- kitty under-text pass
- glyph pass
- kitty over-text pass
- execution completion/result timing

## Why This Counts

This is not file cleanup.

It changes the host story from:

- presenter orchestration plus scattered planning folklore

to:

- presenter orchestration consuming one explicit retained update plan

That is the right direction for a mature terminal host:

- retained surface policy is explicit presenter infrastructure
- retained scratch storage is explicit retained-state ownership

## What Improved

- the partial-plan scratch arrays are no longer treated like random widget
  fields the presenter happens to mutate
- full/partial/shift/fast-path policy is no longer open-coded in the main
  `updateAndPresent(...)` flow
- full and partial retained execution no longer each carry their own separate
  row/span traversal logic for background and glyph passes
- post-update retained readiness/clip/log/present no longer lives as an
  inline tail of mixed branches after update execution
- full and partial retained content no longer each carry their own separate
  kitty/text sequencing body in the main presenter path
- retained-surface bugs now have a clearer planning seam to pressure before
  reading the draw execution branches

## What Still Remains

This front is not done.

The strongest remaining retained contradiction is now narrower:

- presenter execution still mixes:
  - retained update triggering policy
  - sync-update fast-path behavior
  - retained surface present-or-skip top-level policy

So the next honest move is not another planner micro-cut by itself.

It is likely one explicit retained execution contract over:

- sync-update fast path versus retained update/present policy

without reopening generic widget draw glue.
