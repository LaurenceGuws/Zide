# VT War 4 Interaction Slab Ranking

Date: 2026-04-03

## Purpose

Choose the first concrete interaction slab for War 4.

The active question is no longer whether interaction ownership is the next
pressure point. It is which specific slab should open the code war.

## Candidate Slabs

### 1. Output feed / apply

Files:

- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)

Current shape:

- lock
- parser feed
- publication update

Why it is a strong candidate:

- this is the closest Zide equivalent to WezTerm's
  `Terminal.advance_bytes(...)`
- it already revolves around parser + terminal state + publication
- it does not require PTY-writer mechanics
- it is a coherent semantic slab rather than a mixed runtime bag

Risk:

- publication invalidation must stay outside the core even if the feed verb
  becomes more terminal-centered

### 2. Resize / report contract

Files:

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)

Current shape:

- terminal resize and reflow
- transport resize reporting
- optional in-band resize notification

Why it is tempting:

- resize is one of the clearest host-driven terminal verbs

Why it is not first:

- it is more mixed than feed/apply
- transport resize and in-band reporting are clearly runtime concerns
- a bad cut here could collapse transport and terminal semantics together

### 3. Encoded host input semantics

Files:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [input.zig](/home/home/personal/zide/src/terminal/input/input.zig)

Current shape:

- key/text/mouse/focus/reporting
- PTY/external writer encoding
- local-echo fallback for some char input

Why it is important:

- this is where hosts most visibly "talk to the terminal"

Why it is not first:

- it is tightly mixed with writer/transport mechanics
- many verbs here are encoding/runtime concerns, not pure engine semantics
- opening here first risks a much muddier cut than feed/apply

## Ranking

1. output feed / apply
2. resize / report contract
3. encoded host input semantics

## Decision

If War 4 opens into code, it should open on:

- output feed / apply

## Why This Is The Right First Slab

This is the cleanest place to test the new rule:

- terminal-driving semantic verb moves closer to
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- locking and publication remain outside the core
- runtime/transport concerns are not falsely pulled into the engine

If that cut reads better after design, War 4 is real.
If it does not, that is a strong signal that the remaining gap is more about
style and maturity than another real architecture contradiction.

## Bottom Line

War 4 now has a first code target if we continue:

- output feed / apply
