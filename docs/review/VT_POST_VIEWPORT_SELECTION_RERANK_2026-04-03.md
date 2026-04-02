# VT Post-Viewport/Selection Rerank

Date: 2026-04-03

## Purpose

Record the rerank after deleting the dead session mutation facades and moving
live callers onto the real viewport/selection mutation owners.

The question is:

- does the viewport/selection lane still hide another real plug-and-play
  contradiction?

## What Just Improved

The first concrete fallback slice is now landed:

- dead session mutation facades are gone
- live callers now use:
  - [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  - [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)

That matters because the host mutation story no longer teaches a residual
session-shaped layer where there was no real owner.

## Current Read

From the new baseline:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns mutation truth
- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
  now reads like honest:
  - lock ownership
  - publication refresh
  - selection orchestration around core truth
- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  now reads like honest:
  - lock ownership
  - scroll view normalization
  - publication refresh around core truth

That is a materially cleaner ownership line than before.

## What Did Not Emerge

This rerank did not expose another obviously wrong local slab.

What remains in these files now mostly looks legitimate:

- shell lock ownership
- publication refresh / viewport refresh ownership
- host-facing normalization around core-owned mutation truth

So continuing this lane by momentum would likely become another round of local
surface shaving instead of a real plug-and-play win.

## New Judgment

The viewport/selection lane is now close to a stop-marker.

The stronger remaining VT pressure is again the broader one:

- `TerminalCore` sufficiency and overall library-object feel

That is harder, but it is more honest than pretending another small local
mutation cut is waiting here.

## Bottom Line

After the viewport/selection wave:

- the fallback war paid off
- it no longer looks like the next default code war
- the next VT move should only continue if we can name one real remaining
  `TerminalCore` sufficiency slab
- otherwise the honest move is to stop the VT sprint from this baseline
