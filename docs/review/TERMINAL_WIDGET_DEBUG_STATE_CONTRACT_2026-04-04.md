# Terminal Widget Debug State Contract

Date: 2026-04-04

## Purpose

Record the next controller-identity cut after the retained presenter wave.

The problem was no longer just retained-surface planning.

`TerminalWidget` still stored investigation artifacts directly as four
top-level fields:

- view geometry sample
- cursor overlay sample
- retained surface present sample
- text paint sample

That kept the widget shell reading like the default storage site for whatever
the current terminal investigation needed.

## What Changed

`src/ui/widgets/terminal_widget_debug_geometry.zig`
now owns one explicit debug-sample storage contract through:

- `DebugCaptureState`

`src/ui/widgets/terminal_widget.zig`
now holds:

- `debug: DebugCaptureState`

instead of four separate top-level sample fields.

Live writers and readers now consume that explicit owner through:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
- `src/ui/widgets/terminal_widget_surface_presenter.zig`
- `src/ui/widgets/terminal_widget_debug_capture.zig`

## Why This Counts

This is not naming cleanup.

It improves controller identity by making investigation/sample state read like
one explicit debug subsystem instead of four incidental widget-shell fields.

That is the correct direction for the hosting design:

- debug capture remains useful
- but the main widget controller is less obviously the default home for
  investigation artifacts

## What Improved

- debug sample ownership is explicit now
- draw, overlay, presenter, and dump helpers all read/write the same named
  debug owner
- `TerminalWidget` is slightly less of a grab bag of unrelated state buckets

## What Still Remains

This does not finish controller identity.

The widget shell still owns several different state families at once:

- focus / blink / recent input
- pending open / presentation feedback
- selection gesture state
- kitty state
- retained state
- draw cache

So the next honest controller-identity question is stronger than debug storage:

- which of those still belong directly on the widget controller
- and which should move behind a more explicit host-side owner
