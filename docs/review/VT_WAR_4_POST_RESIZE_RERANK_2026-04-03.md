# VT War 4 Post-Resize Rerank

Date: 2026-04-03

## Purpose

Rerank War 4 after the first two interaction slabs:

- output feed / apply
- resize / report contract

The goal is to decide whether the third slab, encoded host input semantics,
should open next or whether War 4 is now close enough to diminishing returns
to require a stricter design bar.

## What Is Now Materially Better

### 1. Output application is now one coherent semantic slab

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns `feedOutputBytesLocked(...)`
- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  is narrowed to shell locking plus publication handoff
- runtime parse paths now use that same core-owned verb too

### 2. Resize semantics now have the same ownership line

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns `resizeLocked(...)`
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  still owns shell locking and transport/reporting

That means War 4 already has two real wins using the same rule:

- semantic terminal behavior toward core
- locking/transport/reporting outside core

## Remaining Candidate

The next obvious candidate is still:

- encoded host input semantics

Files:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [terminal/input/input.zig](/home/home/personal/zide/src/terminal/input/input.zig)
- [terminal_transport.zig](/home/home/personal/zide/src/terminal/core/runtime/terminal_transport.zig)

## Why It Is Harder

Unlike feed/apply and resize:

- key/text/mouse/focus/reporting are tightly coupled to writer mechanics
- `session/input.zig` mixes:
  - host interaction semantics
  - protocol/mode decisions
  - direct writer encoding paths
  - transport availability fallbacks
- many callers use `session_input.*` directly from widgets, FFI, and app code

That makes this slab much easier to cut badly.

## Current Judgment

Do not open encoded host input by momentum.

If War 4 continues, it should continue only after one more deliberate design
step that names the exact sub-slab inside input, such as:

- text send / byte send
- focus and color-scheme reporting
- key/char semantic dispatch before writer encoding
- mouse/reporting behavior versus pure writer protocol encoding

## Ranking

1. output feed / apply
   Status: materially coherent enough to stop
2. resize / report contract
   Status: first slice landed cleanly
3. encoded host input semantics
   Status: still the next candidate, but not yet a safe immediate cut

## Bottom Line

War 4 is no longer in a state where the next move is obvious extraction.

The first two interaction slabs were real.
The third slab now needs a fresh design pass before code, or the honest move
is to stop and rerank from the new baseline.
