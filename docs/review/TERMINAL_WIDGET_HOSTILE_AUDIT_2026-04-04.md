# Terminal Widget Hostile Audit

Date: 2026-04-04

## Purpose

Re-open full scrutiny of the native terminal widget stack from the current VT
maturity standard.

This is not a local follow-up to one cursor bug.
It is a hostile read of whether the terminal widget still teaches the wrong
terminal-hosting story:

- too much direct VT/session knowledge in widget code
- too much renderer/present-path policy mixed with terminal draw semantics
- too much hot-path optimization logic carrying duplicated semantic policy

That matters directly to the main war:

- if the widget only hosts Zide VT cleanly through custom glue, then the host
  side is still teaching a weaker library story than Ghostty/WezTerm
- if the widget can host a mature VT object only by knowing too many
  Zide-specific seams, then `TerminalCore` maturity gains are being partially
  undercut at the host edge

## Why This Reopened

The older stop-marker in
`docs/todo/terminal/widget_boundary_split.md`
was too permissive from the current standard.

Recent bugs proved the widget still contains real architectural pressure:

- retained terminal surface drift at fractional scale
- alt-screen / `nvim` block cursor glyph color missing in the optimized draw
  path

Those were not random defects.
They came from the same structural issue:

- one widget stack still owns too many responsibilities
- semantic policy is duplicated across optimized branches
- renderer policy, host policy, and VT-facing behavior still meet in too many
  ad hoc places

## Inventory

Main files under scrutiny:

- `src/ui/widgets/terminal_widget.zig`
  - widget shell, draw cache, focus/blink state, selection gesture state,
    pending open, retained-state ownership, debug dump ownership
- `src/ui/widgets/terminal_widget_draw.zig`
  - draw orchestration, retained-surface update policy, partial/full redraw
    choice, kitty pass ordering, overlay sequencing, frame metrics
- `src/ui/widgets/terminal_widget_draw_grid.zig`
  - background runs, cursor-aware row splitting, direct glyph path, shaped
    glyph path, special glyph path, fallback path, text-paint debug capture
- `src/ui/widgets/terminal_widget_draw_texture.zig`
  - partial damage plan, viewport-shift plan, full-frame fast-path heuristics
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
  - selection, hover underline, cursor overlay painting
- `src/ui/widgets/terminal_widget_input.zig`
  - input orchestration across hover, keyboard, pointer, open, mouse
    reporting, OSC clipboard handoff
- `src/ui/widgets/terminal_widget_keyboard.zig`
  - key/text dispatch, focus reports, scrollback reset, widget dump hotkey
- `src/ui/widgets/terminal_widget_pointer.zig`
  - selection gestures, scrollback drag, alternate scroll, middle-click paste
- `src/ui/widgets/terminal_widget_open.zig`
  - ctrl-open hyperlink/path extraction and cwd-relative resolution
- `src/ui/widgets/terminal_widget_mouse_reporting.zig`
  - SGR/X10 mouse reporting dispatch with direct session locking
- `src/ui/widgets/terminal_widget_hover.zig`
  - hover hit-testing and underline drawing
- `src/ui/widgets/terminal_widget_view_state.zig`
  - ad hoc read-model extraction from `RenderCache`
- `src/ui/widgets/terminal_widget_kitty.zig`
  - kitty image texture lifecycle and layering in widget draw
- `src/ui/widgets/terminal_widget_paste.zig`
  - native paste policy and bracketed/OSC 5522 fallback
- `src/ui/widgets/terminal_widget_retained_state.zig`
  - retained texture and partial-plan state
- `src/ui/widgets/terminal_widget_draw_metrics.zig`
  - global frame-latency reporting

Scale of the current stack:

- `terminal_widget_draw_grid.zig`: 1470 lines
- `terminal_widget_draw_texture.zig`: 1220 lines
- `terminal_widget_draw.zig`: 796 lines
- `terminal_widget.zig`: 641 lines
- `terminal_widget_keyboard.zig`: 423 lines
- `terminal_widget_kitty.zig`: 377 lines
- `terminal_widget_open.zig`: 362 lines

## Findings

### 1. `TerminalWidget` is still an integration bucket, not a narrow host view

`src/ui/widgets/terminal_widget.zig` still owns all of these at once:

- session handle
- focus reporting state
- blink pause state
- selection gesture state
- hover state
- pending open request
- retained terminal texture state
- kitty renderer state
- presentation feedback staging
- draw cache lifetime
- geometry/debug dump state

That is wider than a clean host/widget shell.

The problem is not just file size.
The problem is that the widget object still feels like the place where
"whatever the terminal needs" gets stored if no cleaner seam already exists.

### 2. The draw pipeline is not one responsibility

`src/ui/widgets/terminal_widget_draw.zig` currently owns all of these in one
path:

- snapshot handoff from publication
- terminal view-geometry resolution
- retained surface sizing and recreation
- full vs partial update policy
- viewport-shift scroll fast path
- partial-plan allocation and build
- kitty under/over text passes
- background pass
- glyph pass
- overlay pass
- presentation feedback staging
- frame timing metrics

This is not just "draw the terminal."
It is a combined:

- publication consumer
- retained-surface presenter
- damage planner
- terminal renderer
- performance probe

That makes the draw path hard to trust because correctness and optimization
policy are forced to co-evolve inside one file.

### 3. `terminal_widget_draw_grid.zig` is architecturally overburdened

The recent alt-screen / `nvim` cursor bug is the clearest evidence.

This file currently mixes:

- resolved terminal cell color policy
- cursor coverage policy
- background run merging
- direct glyph fast path
- shaped glyph path
- special glyph sprite path
- fallback glyph path
- cursor-aware row splitting for shaping
- blink filtering
- text-paint debug capture
- glyph draw stats

The row split around the cursor is not automatically wrong.
It serves a real shaping/ligature purpose.

The real problem is that semantic policy is duplicated across multiple
optimization branches.

That is how the block-cursor glyph inversion bug happened:

- block-cursor background logic existed
- block-cursor glyph logic existed
- but not every optimized glyph branch consumed the same resolved cursor-cell
  policy

This file is now the highest-risk sign that hot-path optimization has outgrown
its current ownership shape.

### 4. The widget input path is fragmented and still session-shaped

`src/ui/widgets/terminal_widget_input.zig` fans out into:

- hover updates
- ctrl-open
- OSC clipboard host handoff
- keyboard dispatch
- pointer selection/scrollback handling
- mouse reporting

Then the sub-files reach directly into session/core APIs:

- `terminal_widget_keyboard.zig`
  - focus reports
  - scrollback reset
  - direct char/key sends
  - debug-dump hotkey
- `terminal_widget_pointer.zig`
  - selection clear/start/extend/finish
  - scrollback follow-live reset
  - selection drag autoscroll
  - alternate scroll wheel reporting
- `terminal_widget_mouse_reporting.zig`
  - direct session locking plus raw mouse event emission
- `terminal_widget_paste.zig`
  - native paste policy plus protocol fallback ordering
- `terminal_widget_open.zig`
  - cwd and hyperlink host queries plus token/path parsing

This means the terminal widget does not consume one clean "terminal host input"
contract yet.
It still knows too many individual session verbs.

### 5. The retained terminal surface is still widget-owned policy, not a clear renderer-owned subsystem

`src/ui/widgets/terminal_widget_draw_texture.zig` and
`src/ui/widgets/terminal_widget_retained_state.zig` together define a retained
terminal-present system with:

- viewport-shift policy
- partial redraw planning
- row-span plan storage
- full-frame fast-path threshold logic
- blink-damage widening
- cursor-column aggregate logic

The logic itself is not obviously wrong.
The ownership is.

This is renderer/presenter infrastructure, but it still lives as terminal
widget-private planning state instead of a named renderer-owned terminal
surface presenter.

That is why terminal rendering bugs are still easy to misdiagnose as widget
bugs, renderer bugs, or VT bugs depending on which branch you read first.

### 6. `terminal_widget_view_state.zig` is an ad hoc mirror over `RenderCache`

This file exports many small derived structs:

- `ViewportInfo`
- `ScrollbarInfo`
- `LifecycleTransitionInfo`
- `PartialCaptureInfo`
- `RenderStateInfo`
- `DirtySummary`
- `DrawStateInfo`
- `BaseColorInfo`
- `VisibleViewDumpInfo`

This is useful, but it is also a smell:

- draw, input, debug, and diagnostics are each pulling slightly different read
  models from the same cache
- there is still no single terminal-view read model that the full widget stack
  consumes consistently

The result is less duplication than raw cache reach, but still too much local
pick-and-choose interpretation.

### 7. Widget debug and investigation ownership is too deep

`src/ui/widgets/terminal_widget.zig` now owns:

- visible-view dump assembly
- geometry diagnostics formatting
- cursor-vs-text delta reporting
- retained-surface vs view delta reporting
- non-ascii cell dumps
- background-run dumps

This was useful for debugging.
It was the right short-term move while fixing real bugs.

But it also means the main widget object has become the default place where
rendering investigations accumulate.

That increases the odds that debug-only seams quietly become architecture.

### 8. Test coverage is skewed toward damage heuristics, not widget contract integrity

The current tests are strongest in:

- partial-plan building
- viewport-shift planning
- full-frame fast-path thresholds
- kitty z-layer policy
- one keyboard shortcut edge case

They are weak in:

- full-widget cursor semantics
- retained-surface equivalence versus live-grid draw
- overlay/grid semantic agreement
- hyperlink/open invariants
- hover/input geometry invariants
- alt-screen correctness at the widget layer

That is exactly the shape you would expect from a stack where performance and
damage-path sophistication advanced faster than ownership normalization.

## Current Judgment

The earlier "terminal widget is now mostly legitimate host/widget glue" read is
too generous.

The terminal widget is no longer obvious sludge, but it is still not clean
enough for the VT-hosting standard we now want.

Bluntly:

- `TerminalCore` can keep getting purer
- but if the terminal widget still knows this much session/publication/present
  detail
- then the host side is still teaching a custom terminal story instead of a
  boring library-hosting story

That does not mean every current responsibility is wrong.
It means the current seams are still too accidental.

## Proposed High-Level Target

The widget stack should be re-read as five explicit ownership zones.

### 1. `TerminalWidgetController`

Own only pane-local host/widget state:

- focus state
- hover state
- pending open request
- pointer drag gesture state
- blink pause / recent input timing if it remains UI-owned

It should not own large draw/debug/present machinery directly.

### 2. `TerminalViewModel`

One read model derived from publication/cache for the whole terminal widget
front.

It should centralize:

- viewport truth
- cursor truth
- draw-visible rows/cols
- alt/sync/dirty summary
- base colors
- cell slices for draw/input/open/hover

This replaces the current scatter of micro-struct helpers from
`terminal_widget_view_state.zig`.

### 3. `TerminalSurfacePresenter`

Own retained terminal surface policy:

- retained texture lifecycle
- full/partial redraw choice
- viewport shift plan
- partial damage plan
- presentation feedback handoff
- scene-target invalidation linkage

This should read like renderer/presenter infrastructure, not generic widget
state.

### 4. `TerminalGridPainter`

Own terminal cell rendering with one shared resolved-cell-style pipeline.

It should centralize:

- resolved cell colors
- cursor-cell style overrides
- blink/reverse policy
- direct vs shaped vs special vs fallback branch selection

The rule should be:

- semantic cell style is resolved once
- optimization branches consume that resolved style
- they do not each reinvent cursor/background/foreground policy

### 5. `TerminalInputAdapter`

Own host input mapping into terminal actions.

It should present one smaller action contract instead of raw widget files each
calling different session/core verbs.

This is where we should draw the clean line between:

- widget hit-testing and host clipboard/open state
- terminal actions such as key/text/mouse/selection/viewport commands

## Recommended Front Order

### Front 1. Freeze the hostile inventory and stop-marker

Required outcome:

- explicitly record that the older widget-boundary stop-marker is superseded
- keep this audit as the evidence baseline

### Front 2. Introduce one `TerminalViewModel`

Why first:

- draw, input, open, hover, and debug are all still deriving overlapping truth
  from `RenderCache`
- without one read model, later cuts will just reshuffle helpers

### Front 3. Split `TerminalSurfacePresenter` out of `terminal_widget_draw.zig`

Why next:

- the retained-surface/damage/present path is the cleanest large seam that is
  different in kind from input and cell semantics

### Front 4. Centralize resolved cell style in the grid painter

Why:

- the recent cursor bug came directly from semantic policy duplication across
  optimized draw branches
- this is the highest-risk correctness seam inside the painter

### Front 5. Collapse input into a smaller terminal action contract

Why:

- the current widget input stack still knows too many direct session/core verbs
- this is the place most likely to keep Zide VT hosting non-swappable

### Front 6. Push debug ownership out of the main widget shell

Why last:

- the debug seams are useful right now
- but they should end as explicit debug helpers, not long-term widget identity

## Bar For Success

This lane is not done when files are smaller.

It is done when:

- the widget reads like a host of a mature terminal object, not a co-owner of
  terminal behavior
- optimized draw branches no longer duplicate cursor/cell semantic policy
- retained terminal surface logic reads like presenter infrastructure, not
  widget-local folklore
- input paths consume a smaller terminal action contract instead of scattered
  session verbs
- a strong maintainer can imagine swapping in a peer VT with limited host
  adaptation instead of rewriting the widget stack around it
