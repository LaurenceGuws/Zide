# Terminal Widget Surface State Contract

Date: 2026-04-04

## Purpose

Record the next widget-host ownership cut after controller and publication
state were made explicit.

The remaining problem was no longer raw publication/cache ownership or loose
controller fields.

`TerminalWidget` still directly carried two presenter-side buckets:

- kitty image presentation state
- retained surface state

Those are not controller concerns.
They are both part of the host-side terminal surface/presenter subsystem.

Keeping them as two unrelated top-level widget fields kept teaching the wrong
story:

- the widget shell is still the place where surviving presenter state lands
- instead of one named host-side surface owner

## What Changed

`src/ui/widgets/terminal_widget_surface_state.zig`
now owns one explicit surface-side host contract through:

- `TerminalWidgetSurfaceState`

That owner carries:

- `kitty`
- `retained`
- surface invalidation
- alt-screen lifecycle transition tracking
- kitty prepare/finish draw hooks
- retained texture-readiness/read-generation accessors

`src/ui/widgets/terminal_widget.zig`
now holds:

- `surface: TerminalWidgetSurfaceState`

instead of separate top-level `kitty` and `retained` fields.

Live consumers were rewired through that owner in:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_surface_presenter.zig`

## Why This Counts

This is not just bundling fields.

It changes the host-side identity story:

- kitty and retained state now read like one presenter/surface bucket
- the widget shell no longer teaches that those presenter concerns are just
  more ambient widget baggage
- draw and presenter code now consume a named surface owner instead of two
  separate top-level widget fields

That is closer to the design bar:

- controller state
- publication state
- surface state
- debug state

instead of one large widget shell plus a shrinking pile of leftover field
families.

## What Improved

- kitty lifecycle and retained lifecycle are grouped as one host-side surface
  owner
- alt-screen lifecycle transition tracking is no longer a loose retained-state
  detail on the widget shell
- invalidate-texture and kitty prepare/finish draw now read like surface owner
  behavior
- handoff logging now reads retained readiness/generation through the surface
  owner instead of direct top-level widget fields

## What Still Remains

This does not finish the widget scrutiny lane.

The main widget shell is now materially flatter:

- `session`
- `controller`
- `publication`
- `surface`
- `debug`

So the next honest question is no longer "what other field bucket can be
grouped."

It is:

- whether `TerminalWidgetSurfacePresenter` still hides one more real
  presenter-policy contradiction
- or whether the widget stack is now close enough to rerank honestly against
  the broader VT host-side maturity bar
