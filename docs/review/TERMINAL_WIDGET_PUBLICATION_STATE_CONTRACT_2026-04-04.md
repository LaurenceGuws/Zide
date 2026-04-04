# Terminal Widget Publication State Contract

Date: 2026-04-04

## Purpose

Record the next host-side widget ownership cut after controller-state cleanup.

The remaining contradiction was no longer loose controller state.

`TerminalWidget` still directly owned publication/cache truth through:

- `draw_cache` storage
- `prepareLatestPresentation(...)` handoff
- ad hoc `RenderCache` reads in draw, input, paste, debug, presenter logic

That kept the widget shell reading like the default storage site for terminal
publication state instead of an orchestrator consuming an explicit read/capture
owner.

## What Changed

`src/ui/widgets/terminal_widget_publication_state.zig`
now owns one explicit publication-side host contract through:

- `TerminalWidgetPublicationState`

That owner carries:

- `RenderCache` lifetime
- latest publication capture preparation
- widget-facing `TerminalViewModel` derivation

`src/ui/widgets/terminal_widget.zig`
now holds:

- `publication: TerminalWidgetPublicationState`

instead of `draw_cache` directly.

Live consumers were rewired through that owner in:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/ui/widgets/terminal_widget_debug_capture.zig`
- `src/ui/widgets/terminal_widget_paste.zig`
- `src/ui/widgets/terminal_widget_surface_presenter.zig`
- `src/app/post_preinput_hooks_runtime.zig`

## Why This Counts

This is not cosmetic field renaming.

It improves the widget-host story materially:

- the widget shell no longer directly owns publication cache storage
- latest capture handoff is no longer inlined against raw cache storage on the
  widget shell
- draw/input/debug/paste/presenter code now consume one named publication
  owner instead of reaching `draw_cache` as ambient widget baggage
- app-side cursor-blink logic now consumes terminal view truth instead of raw
  cache fields

That is closer to the maturity bar:

- explicit controller state
- explicit publication state
- explicit presenter state
- explicit debug state

instead of one shell object that still quietly stores every surviving host-side
terminal concern.

## What Improved

- publication cache lifetime is explicit
- publication capture preparation is explicit
- widget-facing terminal read truth now has one local owner to pressure
- the widget shell is less obviously the storage site for terminal publication
  internals

## What Still Remains

This does not finish the widget lane.

The surviving top-level widget buckets are now narrower and more deliberate:

- `kitty`
- `retained`
- `debug`
- `controller`
- `publication`

The next honest question is no longer publication/cache ownership.

It is whether the strongest remaining contradiction is:

- retained/presenter policy still spanning `retained` and presenter execution
- kitty host-side rendering state still teaching the wrong ownership story
- or whether the widget is now close enough to a stop-marker to rerank against
  the broader VT maturity bar
