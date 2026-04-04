# Terminal Widget Controller State Contract

Date: 2026-04-04

## Purpose

Record the next structural controller-identity cut after the retained
presenter and debug-state work.

The problem was no longer only retained-surface policy or debug sample
storage.

`TerminalWidget` still stored several different pane-local controller
concerns directly as loose top-level fields:

- focus-reporting state
- UI focus state
- hover state
- blink/recent-input state
- pending open request
- pending presentation feedback
- selection press/drag/gesture state

That kept the widget shell reading like a bag of unrelated coordination
details instead of one explicit controller owner.

## What Changed

`src/ui/widgets/terminal_widget_controller_state.zig`
now owns one explicit controller-local state contract through:

- `TerminalWidgetControllerState`
- `FocusUiState`
- `BlinkUiState`
- `PendingActionState`
- `SelectionGestureState`

`src/ui/widgets/terminal_widget.zig`
now holds:

- `controller: TerminalWidgetControllerState`

instead of those focus/blink/pending/selection fields directly.

Live consumers were rewired to that owner through:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/ui/widgets/terminal_widget_pointer.zig`
- `src/ui/widgets/terminal_widget_surface_presenter.zig`

## Why This Counts

This is not just one more state-bag extraction.

It changes the widget-host story in a concrete way:

- pane-local controller state is now named as one host-side owner
- the widget shell no longer teaches that focus, hover, blink, selection, and
  pending action state are just whatever fields happened to accumulate there
- draw, input, retained-present heuristics, and public widget methods now all
  consume the same explicit controller state

That is materially closer to the design bar:

- `TerminalWidget` as controller/orchestrator
- explicit helper owners for presenter, painter, input, debug, and now
  controller-local state

## What Improved

- hover state is grouped with the rest of pane-local controller state
- focus-reporting and UI focus transitions are grouped under one state owner
- blink timing, blink phase-change consumption, and recent-input heuristics
  are grouped under one state owner
- pending open request and pending presentation feedback are grouped under one
  state owner
- selection gesture and drag threshold state are grouped under one state
  owner
- retained fast-path heuristics no longer read raw widget timing fields

## What Still Remains

This does not finish widget-controller identity.

The widget shell still directly owns several heavier host-side buckets:

- `kitty`
- `retained`
- `draw_cache`
- `debug`

Some of those are probably honest survivors.
Some may still need stricter naming or narrower ownership.

So the next honest rerank is no longer "can we move another random field."

It is:

- whether the remaining top-level widget buckets now read like deliberate
  controller/presenter/cache state
- or whether one of them still teaches the wrong host-side terminal story
