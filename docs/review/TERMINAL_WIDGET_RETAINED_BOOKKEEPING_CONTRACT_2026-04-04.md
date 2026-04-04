# Terminal Widget Retained Bookkeeping Contract

Date: 2026-04-04

## Purpose

Record the next presenter-side surface-state cut after kitty and retained
state were grouped under one `surface` owner.

The remaining contradiction was no longer top-level widget storage.

`terminal_widget_surface_presenter.zig`
still directly poked retained bookkeeping all over the presenter flow:

- generation tracking
- clear-generation tracking
- cell-metric tracking
- render-scale tracking
- texture-ready tracking
- target-availability fallback
- partial-plan access

That meant the `surface` owner existed, but the presenter was still reading and
mutating retained internals directly instead of consuming one explicit retained
contract through that owner.

## What Changed

`src/ui/widgets/terminal_widget_surface_state.zig`
now owns the retained bookkeeping contract through:

- `RetainedUpdateDelta`
- `retainedUpdateDelta(...)`
- `noteRetainedSurfaceUpdated(...)`
- `noteRetainedTargetAvailability(...)`
- `ensurePartialDrawPlan(...)`

`src/ui/widgets/terminal_widget_surface_presenter.zig`
now consumes that contract instead of directly mutating retained bookkeeping
fields across:

- retained update planning
- retained present readiness refresh
- sync-update fast-present readiness
- retained generation reads for present

## Why This Counts

This is not helper motion.

It changes the dependency story inside the presenter:

- retained readiness and update deltas now come from the surface owner
- retained update completion now goes back through the surface owner
- the presenter is less of a second home for retained bookkeeping truth

That is the right direction from the current widget-host design bar:

- `surface` should be a real surface-side owner
- not just a bag that still requires direct retained-state field pokes from
  presenter code

## What Improved

- retained update planning reads one explicit delta contract
- retained readiness state is refreshed through one explicit surface method
- partial-plan access is now requested from the surface owner
- present-time retained generation reads now go through surface accessors

## What Still Remains

This does not prove the widget lane is finished.

But it does materially narrow the surviving presenter question:

- there is no longer a broad retained bookkeeping leak
- the next contradiction, if one still exists, must be a higher-level
  presenter policy seam
- not another round of raw retained field access cleanup
