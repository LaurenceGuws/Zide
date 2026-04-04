# VT Core Geometry Margin Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining viewport-geometry parameter slab that still made
CSI execution normalize terminal geometry and margin semantics from raw screen
state instead of `TerminalCore`.

## Current Judgment

After the text and DECRQSS cuts, one small but honest terminal-semantic pocket
still bypassed `TerminalCore`:

- scroll-region parameter normalization for `CSI r`
- left-right margin mode gating and parameter normalization for `CSI s`

That kept one viewport-geometry slab reading protocol-owned in
[csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig).

## Exact Line

The pressure was concentrated in:

- [csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig)

## Required Bar

The move must not be:

- another CSI helper split that still leaves geometry truth on the protocol
  side

It must:

- move scroll-region and left-right-margin parameter semantics onto
  `TerminalCore`
- leave CSI framing and save-cursor fallback outside core

## Progress

The first whole slab is now landed.

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- `setScrollRegionFromParamsLocked(...)`
- `setLeftRightMarginsFromParamsLocked(...)`

What changed:

- [csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig)
  no longer computes rows/cols bounds and left-right-margin mode gating from
  raw screen state
- CSI now delegates those terminal geometry semantics directly to core

## Current Read

This is a smaller but real `TerminalCore` sufficiency win:

- viewport geometry semantics are flatter at the CSI edge
- protocol code now reads more like framing plus fallback, less like the owner
  of terminal geometry truth

## Decision

Do not reopen this slice unless one stronger remaining geometry/margin pocket
still clearly bypasses `TerminalCore`.

The next default pressure returns to the broader `TerminalCore` sufficiency
rerank from this cleaner geometry baseline.
