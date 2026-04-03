# VT Post Execution Rerank

Date: 2026-04-03

## Purpose

Rerank the VT maturity campaign after the recent execution-contract wave:

- feed/apply effects
- selection effects
- viewport refresh consumer

The question is whether category 1 still outranks category 2, and if so, what
the next real category-1 war actually is.

## Current Read

Category 1 still wins.

But the form of category 1 has changed.

The next war is not:

- generic `TerminalCore` sufficiency discomfort
- parser-owner extraction by momentum

The next war is:

- mixed protocol interaction state that still prevents parser/protocol
  execution from becoming more terminal-centered cleanly

## Why Category 1 Still Wins

Recent wins reduced a real part of the contradiction:

- outer publication completion is more explicit now
- selection and viewport mutation no longer repeat the same refresh
  choreography inline

But the deeper blocker remains inside terminal-driving protocol execution.

The new evidence is:

- [VT_CORE_PARSER_OWNER_DESIGN_2026-04-03.md](/home/home/personal/zide/docs/review/VT_CORE_PARSER_OWNER_DESIGN_2026-04-03.md)
- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)

Those paths still mix:

- terminal semantics
- session interaction flags
- writer/reporting mechanics

That is still a more fundamental maturity blocker than broad FFI discomfort.

## Why Category 2 Does Not Overtake Yet

Public contract normalization is still real, especially across:

- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)

But right now that category still reads more like:

- a broad, bespoke host edge over an increasingly serious terminal center

not:

- the primary thing keeping the terminal object from feeling mature

The stronger root problem is still inside the terminal/protocol boundary.

## New Ranked Order

1. mixed protocol interaction state blocking deeper `TerminalCore` maturity
2. public contract normalization and host-edge story
3. shell legitimacy guardrail only
4. interaction ownership paused unless a new semantic slab appears
5. mutation/publication maturity paused unless a new contradiction appears

## Named Next War

If VT continues immediately, the next war should be:

- protocol interaction contract war

Meaning:

- identify which interaction/reporting/runtime flags currently living under
  `session.interaction` should become a cleaner explicit contract beside core
- so parser/protocol execution can become more terminal-centered without
  pulling writer/reporting/runtime mechanics into `TerminalCore`

This is a design-first war.

Not:

- a direct parser extraction
- a direct FFI cleanup pass

## What Must Stay Paused

Do not reopen by momentum:

- more execution-effect micro-cuts
- broad FFI narrowing
- shell-thinning
- host-query cleanup

Those are no longer the strongest maturity pressure.

## Bottom Line

The execution-contract wave changed the board.

The strongest remaining VT blocker is still category 1, but now in a sharper
form:

- mixed protocol interaction state is what still blocks deeper
  `TerminalCore` maturity

That is the next thing worth naming and designing.
