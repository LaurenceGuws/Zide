# VT Core Resize Owner Front

Date: 2026-04-04

## Purpose

Name the next exact broader `TerminalCore` sufficiency contradiction after the
mode/reset front reached its stop-marker.

## Current Judgment

The next live contradiction is resize owner dependency.

This is where `TerminalCore` still most clearly reads like:

- core owns the idea of resize/reflow
- outer owner shape still completes that operation through:
  - host cell-metric staging
  - scroll-view publication refresh
  - transport resize reporting

## Live Pressure

The pressure is concentrated in:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - `resizeLocked(_, owner, rows, cols)`
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  - `resizeInternal(...)`
  - `resizeCoreLocked(...)`

The active mixed story is visible directly:

- terminal reflow and selection remap are core-shaped semantics
- cell-width / cell-height staging is host-contract state
- `publication_flow.refreshScrollViewLocked(...)` is explicit outer publication
- transport `resize(...)` is explicit runtime/PTY work

## Why This Beats Other Candidates

It beats:

- reopening mode/reset after its stop-marker
- reopening generic parser-feed discomfort
- reopening shell cleanup by momentum

Because resize is still a central terminal operation that reads less mature
than it should:

- `TerminalCore` exposes resize as its method
- but the operation still requires a broad outer owner to become complete

That is a stronger first-glance maturity loss than lifecycle-shaped cleanup
like `deinit(...)`, and a cleaner next target than generic parser discomfort.

## Required Bar

The next move must not be:

- renaming `owner`
- moving `resizeCoreLocked(...)` into a different file
- dragging transport reporting into core
- dragging publication refresh into core

The next move must:

- separate terminal resize/reflow truth from outer resize consequences
- make scroll-view refresh an explicit consumer, not hidden completion
- keep transport resize reporting outside the core boundary

## Decision

The next default VT front is resize owner dependency unless a stronger named
`TerminalCore` contradiction overtakes it immediately.

## Progress

The first resize slice is now landed:

- [TerminalCore.resizeLocked(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now returns explicit `ResizeEffect`
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  no longer performs hidden scroll-view publication refresh inside the core
  resize/reflow path
- outer resize orchestration now consumes that refresh deliberately after the
  core resize effect returns

Why this counts:

- terminal resize/reflow truth is more clearly separated from publication
  consequences
- the core-side resize path no longer finishes itself through hidden
  publication choreography

What remains:

- host cell-metric staging
- transport resize reporting
- any deeper resize-side owner dependence still mixed into the reflow path
