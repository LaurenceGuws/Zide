# VT Core Parser-Owner Design

Date: 2026-04-03

## Purpose

Test whether the next category-1 maturity move should be the deeper
parser-owner dependency inside
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
and [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig).

The question is:

- can we make parser-driven terminal execution feel more core-owned without
  dragging shell/runtime/reporting concerns into core?

## Current Read

Not safely, yet.

The parser-owner line is still too mixed.

Why:

- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
  still executes protocol through a generic session-shaped owner:
  - `handleByte(self, session, byte)`
  - `handleSlice(self, session, bytes)`
- parser dispatch itself is already pushed down into
  [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig),
  but the dispatched handlers still do not terminate on a purely core-owned
  contract

## Mixed Areas Blocking A Clean Move

### 1. CSI execution still mixes terminal semantics with writer/reporting

Concrete evidence:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  directly uses:
  - `lockPtyWriter()`
  - `self.session.interaction.color_scheme_dark`
  - `self.session.interaction.cell_height`
  - `self.session.interaction.cell_width`

This means the same execution path currently mixes:

- terminal state mutation
- runtime writer access
- host-provided display metrics
- reply/report encoding

That is not yet a clean `TerminalCore` execution contract.

### 2. Mode mutation/query still crosses core and session interaction state

Concrete evidence:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  mutates both:
  - terminal state on core/screens
  - session interaction/runtime flags such as:
    - `report_color_scheme_2031`
    - `inband_resize_notifications_2048`
    - `kitty_paste_events_5522`
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  reads the same mixed state from both core and session interaction

So the parser-owner line is blocked by a real mixed contract:

- some mode state is true terminal semantics
- some mode state is host/reporting/runtime contract state

### 3. OSC title/cwd handling still exposes low-level assembly, but that is not
the blocker first

Concrete evidence:

- [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig)
- [osc_util.zig](/home/home/personal/zide/src/terminal/protocol/osc_util.zig)

These still use low-level buffer assembly on core.
That weakens maturity feel, but it is not the reason the parser-owner move is
unsafe right now.

The main blocker is still the mixed session/reporting contract in CSI and mode
handling.

## Decision

Do not force the parser-owner move yet.

If we force it now, the likely failure mode is:

- move parser/protocol execution “toward core”
- but pull writer/reporting/session interaction concerns inward with it
- making `TerminalCore` look less pure, not more mature

That would be fake progress.

## What This Means For The VT Queue

The current execution-contract lane has now yielded three real wins:

1. feed/apply explicit feed effects
2. selection explicit mutation effects
3. viewport shared refresh consumer

The next move should not be:

- a blind parser-owner extraction

The next move should be one of:

1. stop this lane cleanly and rerank category 1 versus category 2 again
2. or open a deeper design-only war around mixed protocol interaction state,
   especially CSI mode/query and reply/report ownership

## Strongest Named Next Design Question

If terminal work continues immediately, the most credible next question is:

- which protocol/runtime interaction state currently living on
  `session.interaction` should become a cleaner explicit contract beside core,
  so parser/protocol execution can become more terminal-centered without
  absorbing runtime mechanics?

That is a real design war.
It is not another small extraction.

## Bottom Line

The parser-owner move is not ready for code yet.

The blocker is explicit:

- protocol execution still mixes true terminal semantics with session
  interaction flags and writer/reporting mechanics

So the honest next step is a rerank or a deeper design war on that mixed
protocol interaction contract, not another immediate cut.
