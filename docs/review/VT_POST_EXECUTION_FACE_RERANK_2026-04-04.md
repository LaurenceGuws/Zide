# VT Post Execution Face Rerank

Date: 2026-04-04

## Purpose

Rerank the active VT scrutiny front after the execution-face cleanup wave.

## Current Judgment

Execution-face cleanup no longer wins by default.

Why:

- the dead runtime compatibility residue is gone from
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
- publication has already lost four coherent contracts:
  1. synchronized updates
  2. parsed-output publication
  3. pending-refresh / poll publication cadence
  4. leftover parsed-output idle/poll residue

At this point, publication does not get to remain the active contradiction by
inertia alone.

## Fresh Read

The remaining publication surface is real, but it is no longer obviously one
coherent execution-face contract.

What remains is spread across broader read/present/publication helpers such as:

- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- [view_cache.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache.zig)
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)

Those surfaces may still contain a real contradiction.

But from this baseline, they no longer beat broader `TerminalCore` sufficiency
without one newly named contract first.

## Decision

Stop execution-face cleanup as the default front.

The next default VT pressure returns to broader
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
sufficiency unless one new exact publication contradiction is named explicitly.
