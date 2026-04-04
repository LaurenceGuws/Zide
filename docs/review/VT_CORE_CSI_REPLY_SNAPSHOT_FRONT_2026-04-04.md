# VT Core CSI Reply Snapshot Front

Date: 2026-04-04

## Purpose

Name and cut the remaining CSI reply-state slab that still made reply
assembly read raw screen and host-metric state directly from protocol code
instead of `TerminalCore`.

## Current Judgment

After the text-owner slice, one cleaner adjacent contradiction remained:

- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  still rebuilt cursor/geometry/cell-metric truth directly from active-screen
  and runtime reads

That was smaller than the broader feed-execution front, but it was clean
enough to land immediately because it removed one more piece of query truth
from protocol-local ownership.

## Exact Line

The pressure was concentrated in:

- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)

## Required Bar

The move must not be:

- reply-sink symmetry work
- or another mixed snapshot bag

It must:

- move terminal-owned reply snapshot truth onto `TerminalCore`
- leave only honest runtime-dependent reply state outside core

## Progress

The first slice is now landed.

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- cursor report position
- rows / cols
- cell metrics

What changed:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now exposes `csiReplySnapshot(...)`
- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  now composes:
  - core-owned reply snapshot truth
  - runtime-owned color-scheme state
- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  now carries only the color-scheme part of the reply runtime snapshot

## Current Read

This is a smaller but real `TerminalCore` sufficiency win:

- CSI reply assembly now reads less like protocol-local screen rummaging
- terminal query truth is flatter at the reply edge
- runtime reply state is narrower and more honest

## Decision

Do not reopen this slice unless one stronger remaining reply/query truth pocket
still clearly bypasses `TerminalCore`.

The next default pressure returns to the broader `TerminalCore` sufficiency
rerank from this cleaner reply baseline.
