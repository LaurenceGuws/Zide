# Terminal Widget Post-Front Rerank

Date: 2026-04-04

## What Changed

The first five widget-hosting fronts all landed:

1. one shared `TerminalViewModel`
2. one named `TerminalSurfacePresenter`
3. one shared resolved cell-style owner in the grid painter
4. one `TerminalInputAdapter` for widget input leaves
5. one explicit debug-capture helper for dump formatting/logging

This materially changed the hosting story.

The widget stack now reads much less like:

- one shell object that owns whatever the terminal front currently needs
- draw branches each inventing their own cursor/cell semantics
- input leaves each reaching directly into different VT/session modules
- debug investigation scripts living inline inside the widget shell

## Current Judgment

This lane should not pause yet.

But the remaining contradiction is narrower and more specific than the opening
audit.

The strongest remaining front is now retained-surface update planning:

- [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
- [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
- [terminal_widget_retained_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_retained_state.zig)

Why this wins:

- presenter ownership is named now, but the retained update policy is still
  split across:
  - full vs partial redraw heuristics
  - viewport-shift planning
  - dirty-span/partial-plan assembly
  - texture-update fast-path decisions
- that split is still more of a host-side maturity contradiction than the
  remaining controller/debug/input residue

What no longer wins:

- generic input cleanup
  - the leaves now consume a named adapter instead of direct VT/session verbs
- debug dump cleanup
  - dump formatting/logging is no longer inline widget-shell ownership
- cell-style semantic duplication
  - cursor/blink/underline/reverse policy now has one shared owner in the grid
    painter

## New Ordering

1. retained-surface update planning and damage ownership
2. only then rerank whether the grid painter's remaining size is hiding a new
   real contradiction
3. only after that consider whether the widget shell itself still teaches the
   wrong identity story

## Hard Warning

Do not treat [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
being large as sufficient reason by itself.

The next slice must improve ownership, not just file size:

- one clearer retained update planner or contract
- not more helper shuffling across presenter and texture files
