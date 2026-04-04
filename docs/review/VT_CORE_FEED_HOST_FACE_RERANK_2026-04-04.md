# VT Core Feed Host Face Rerank

Date: 2026-04-04

## Purpose

Rerank the surviving host-side faces inside the feed-execution front after the
raw interaction bag, mixed host contract, and mixed host metrics were all
split.

## Candidates

1. reporting contract flags
2. cell metrics
3. color-scheme state

## Current Judgment

Cell metrics now win.

Why:

- they still affect more than one active parser/protocol family:
  - CSI reply geometry and pixel answers
  - in-band resize reporting
  - kitty placement dirty-region and implicit span logic
- unlike reporting flags, they are not just explicit host opt-in switches
- unlike color-scheme state, they are not a narrow single-feature pocket

## Weaker Faces

### Reporting Contract Flags

These now read mostly honest.

They are:

- explicit host-reporting opt-in flags
- already isolated from color state and geometry
- closer to a legitimate outer contract than a hidden semantic dependency

### Color-Scheme State

This is narrower than cell metrics.

It still matters for:

- CSI color-scheme preference reply
- host-triggered color-scheme change reporting

But it does not carry the same cross-cutting protocol pressure as cell
metrics.

## Decision

If the feed-execution front continues immediately, the next exact surviving
host-side contradiction is cell-metric dependence.

Do not reopen generic “host contract” cleanup from this baseline.

## Progress

The cell-metric contradiction is now materially cut.

What changed:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns current cell metrics directly
- feed/protocol no longer needs a cell-metrics face on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig),
  [config.zig](/home/home/personal/zide/src/terminal/core/session/config.zig),
  and [terminal_transport.zig](/home/home/personal/zide/src/terminal/core/runtime/terminal_transport.zig)
  now stage and consume cell metrics through `TerminalCore`
- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig),
  [host_reporting.zig](/home/home/personal/zide/src/terminal/core/session/host_reporting.zig),
  and [placement_ops.zig](/home/home/personal/zide/src/terminal/kitty/placement_ops.zig)
  now read cell metrics from core-owned state instead of a host-contract bag

Current judgment after the cut:

- cell metrics no longer survive as a feed-side host face
- the remaining host-side faces are now:
  - reporting contract flags
  - color-scheme state
- the next rerank should decide whether either of those still beats broader
  `TerminalCore` sufficiency
