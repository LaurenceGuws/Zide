# VT CSI Mode Query Split

Date: 2026-04-03

## Purpose

Define the exact contract split for the first battlefield in the protocol
interaction contract war:

- CSI mode/query ownership

The question is not:

- "what field can we move next?"

It is:

- which state currently mixed inside `session.interaction` is actually
  terminal protocol mode state, and which state is host/reporting/runtime
  contract state?

## Current Mixed Container

Today the mixed state lives primarily in:

- [interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig)
- [input_snapshot.zig](/home/home/personal/zide/src/terminal/core/session/input_snapshot.zig)
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)

That container currently holds at least four different categories of state.

## Classified Split

### A. Terminal protocol mode state

These should become the clean terminal-facing mode contract.

They are directly about terminal input/protocol semantics and mode query.

Fields:

- `bracketed_paste`
- `focus_reporting`
- `auto_repeat`
- `app_cursor_keys`
- `app_keypad`
- `mouse_alternate_scroll`
- `input.mouse_mode_x10`
- `input.mouse_mode_button`
- `input.mouse_mode_any`
- `input.mouse_mode_sgr`
- `input.mouse_mode_sgr_pixels_1016`
- `input_snapshot.*` mirrors for those same modes
- `input_snapshot.key_mode_flags`

Reason:

- CSI mode mutation/query already treats these like protocol mode state
- input dispatch already treats these like protocol semantics

### B. Host-reporting contract flags

These are not pure terminal model state.
They govern whether external host/reporting channels are enabled.

Fields:

- `report_color_scheme_2031`
- `inband_resize_notifications_2048`
- `kitty_paste_events_5522`

Reason:

- they matter to protocol query/mutation
- but they are really "what host reporting/services are enabled"
- they should not be mistaken for the same kind of state as app-cursor,
  bracketed paste, or mouse modes

### C. Display metric / live host state

These are host facts used by replies, transport resize, or layout.

Fields:

- `cell_width`
- `cell_height`
- `color_scheme_dark`

Reason:

- they are not protocol mode state
- they are not terminal model truth
- they are host-supplied runtime facts

### D. Derived snapshot state

These are cached mirrors used by input or host code, not true owning state.

Fields:

- `input_snapshot.alt_active`
- `input_snapshot.screen_rows`
- `input_snapshot.screen_cols`

Reason:

- these are snapshots of terminal/display state for cheaper read-side access
- they should not drive ownership decisions by themselves

## Proposed Contract Shape

The next design target should separate these into at least two explicit
contracts:

1. protocol interaction mode state
2. host reporting/display contract state

Possible live owners:

- protocol interaction mode state:
  a new explicit terminal/protocol-facing state owner beside core, or a
  narrower sub-owner under session that is clearly protocol-scoped
- host reporting/display contract state:
  a distinct host/runtime contract owner beside it

The key is not the file count.
The key is that CSI mode/query stops reading one mixed bag as if it were one
kind of thing.

## What This Enables

If this split is done well:

- CSI mode mutation/query can become more terminal-centered
- parser/protocol ownership can move closer to core without pulling host
  reporting or display metrics inward
- `session.interaction` stops teaching one misleading story

## What Does Not Need To Happen

This split does not require:

- moving display metrics onto core
- moving writer/reply mechanics onto core
- narrowing the public ABI yet

It only requires:

- reclassifying mixed protocol state correctly

## Best First Code Slice

After this design is accepted, the best first code slice should be:

- split CSI mode/query reads and writes so terminal protocol mode state is
  accessed separately from host-reporting contract state

Primary files:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig)

That first slice is now landed:

- [interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig)
  now groups:
  - `protocol_modes`
  - `host_contract`
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  now updates protocol mode fields separately from host-reporting flags
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  now queries the same split directly
- the same split now reaches the adjacent consumers that made the old bag feel
  real:
  [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig),
  [interaction.zig](/home/home/personal/zide/src/terminal/core/session/interaction.zig),
  [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig),
  [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig),
  and [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)

## Bottom Line

The first real step in this war is now explicit:

- stop treating `session.interaction` as one kind of state in CSI mode/query

The split is:

- terminal protocol mode state
- host-reporting contract state
- display metric/live host state
- derived snapshot state

Progress now landed beyond the first slice:

- derived snapshot state no longer lives under protocol mode state in the live
  interaction owner
- the input snapshot cache now sits under a separate `derived_snapshot`
  contract, which makes the category-4 boundary explicit in code rather than
  only in this review
