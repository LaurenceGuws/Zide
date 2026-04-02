# VT Viewport/Selection War

Date: 2026-04-03

## Purpose

Open the clearest concrete fallback war after the post-resize rerank:

- viewport and selection mutation still read slightly shell-surfaced

This is not a broad "selection cleanup" pass.
It is a focused plug-and-play cut on whether hosts appear to drive the real
terminal mutation owners directly, or still route through session-era facades.

## Live Problem

Before this cut, live callers commonly went through:

- `src/terminal/core/session/content.zig`
- `src/terminal/core/session/selection.zig`

But those files were not real owners.
They were just forwarding shells over:

- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)

That kept one extra session-shaped layer alive in the host mutation story even
after mutation truth itself had already moved down.

## First Slice

The first concrete slice is now landed:

- widget, FFI, replay, protocol, runtime, and test callers no longer route
  through the session facades
- they now use the real mutation owners directly:
  - [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  - [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
- the two dead facades are deleted:
  - `src/terminal/core/session/content.zig`
  - `src/terminal/core/session/selection.zig`

## Why This Cut Matters

This is not about file count.

It matters because it removes one more residual signal that host-facing
terminal mutation must pass through a session-shaped surface instead of the
actual mutation owners around
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig).

The ownership line is now clearer:

- terminal mutation truth lives on core
- mutation + publication refresh orchestration lives in
  `selection.zig` / `scrollback_view.zig`
- shell/runtime concerns stay outside that

## Current Judgment

This is a real improvement, but still a local slice.

The broader question remains:

- is viewport/selection mutation now honest enough to pause
- or is there still one larger host-facing mutation slab that should feel more
  terminal-owned than it does today

## Bottom Line

The fallback war is now open with the right first cut:

- delete the dead session mutation facades
- make hosts speak the real mutation owners directly
