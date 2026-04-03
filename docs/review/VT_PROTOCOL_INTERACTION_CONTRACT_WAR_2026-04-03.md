# VT Protocol Interaction Contract War

Date: 2026-04-03

## Purpose

Open the next VT maturity war from the post-execution rerank.

The war is not:

- parser-owner extraction by momentum

The war is:

- separate mixed protocol interaction state so parser/protocol execution can
  become more terminal-centered without pulling runtime/reporting mechanics
  into core

## Why This War Exists

The recent execution-contract wave made the remaining blocker sharper.

We can no longer honestly say:

- "the problem is still publication choreography"

The blocker is now:

- protocol execution still mixes true terminal semantics with
  `session.interaction` state and writer/reporting mechanics

The clearest evidence is in:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- [interaction.zig](/home/home/personal/zide/src/terminal/core/session/interaction.zig)
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)

## Classified Mixed State

The important thing is that `session.interaction` is not one kind of thing.

It currently contains at least four different categories.

### 1. Terminal protocol mode state

These are the strongest candidates to move toward a cleaner terminal-centered
contract because protocol execution and mode query treat them like terminal
semantics.

Examples:

- app cursor keys
- app keypad
- auto repeat
- bracketed paste
- focus reporting enablement
- mouse alternate scroll
- mouse reporting modes
- key mode flags snapshot

Concrete files:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)

### 2. Host-reporting contract flags

These do not read like pure terminal model state.
They read like "what external host reporting channels are enabled."

Examples:

- `report_color_scheme_2031`
- `inband_resize_notifications_2048`
- `kitty_paste_events_5522`

Concrete files:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- [interaction.zig](/home/home/personal/zide/src/terminal/core/session/interaction.zig)
- [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)

### 3. Display metric / host geometry state

These are not terminal semantics.
They are host-provided facts used for replies, transport resize, kitty layout,
and in-band notifications.

Examples:

- `cell_width`
- `cell_height`
- `color_scheme_dark`

Concrete files:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
- [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)
- [placement_ops.zig](/home/home/personal/zide/src/terminal/kitty/placement_ops.zig)

### 4. Screen/model semantics mirrored into interaction snapshots

Some snapshot fields are derived from terminal state and exist only so input
or host code can read them without reaching deep.

Examples:

- `alt_active`
- `screen_rows`
- `screen_cols`
- key mode snapshot

Concrete files:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)

## War Hypothesis

The next real maturity gain is not moving parser execution into core directly.

It is separating category 1 from categories 2 and 3 well enough that parser
and protocol code can depend on a cleaner terminal-facing interaction contract.

That would let us say:

- terminal protocol mode state is terminal-centered
- host reporting/runtime state is adjacent contract state
- display metrics remain host/runtime facts

Instead of:

- one mixed `session.interaction` bag participates in all of those roles

## First Ranked Targets

### 1. CSI mode/query contract

This is the best opening target.

Why:

- it touches both mutation and query
- it already shows the mixed categories clearly
- it is central to parser/protocol ownership feel

Primary files:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)

Current design authority for that split:

- [VT_CSI_MODE_QUERY_SPLIT_2026-04-03.md](/home/home/personal/zide/docs/review/VT_CSI_MODE_QUERY_SPLIT_2026-04-03.md)

### 2. CSI reply/report contract

This is second.

Why:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  still mixes reply encoding with host metrics and runtime writer access
- but it is less obviously separable than the mode/query split

Progress now landed:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  no longer hand-assembles DSR/window-op reply inputs inline from mixed shell
  reads
- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  now owns one explicit `Snapshot` for:
  - cursor position
  - rows/cols
  - cell metrics
  - color-scheme preference
- writer ownership still stays outside that contract, but reply/report state is
  now named and explicit instead of ad hoc inside the CSI switch

### 3. Kitty/reporting interaction flags

This is third.

Why:

- it is real
- but it is narrower and more special-purpose than the CSI mode/query center

## What Would Count As Progress

Real progress would be:

- one explicit contract split between terminal protocol mode state and
  host-reporting/runtime contract state
- one result where parser/protocol code reads more terminal-centered without
  moving writer/reporting mechanics into core

Progress now landed:

- [interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig)
  no longer stores one flat interaction bag
- the first live split is explicit in code:
  - `protocol_modes`
  - `host_contract`
- CSI mode mutation/query now read and write those categories separately
- input/runtime/transport users that depended on those same fields were
  rewired to the same split, so the new contract is not CSI-only theater

Fake progress would be:

- renaming `session.interaction`
- moving helpers while leaving the same mixed ownership
- extracting parser code without reclassifying the underlying state

## Bottom Line

The next VT war is now explicit:

- protocol interaction contract war

And the first serious battlefield inside it is:

- CSI mode/query ownership

The first code slice for that battlefield is now in:

- terminal protocol mode state under `session.interaction.protocol_modes`
- host-reporting/display contract state under `session.interaction.host_contract`
