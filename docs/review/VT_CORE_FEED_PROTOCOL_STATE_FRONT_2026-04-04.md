# VT Core Feed Protocol State Front

Date: 2026-04-04

## Purpose

Name the next surviving face inside the broader feed-execution contradiction
after publication/update slicing reached its stop-marker.

## Current Judgment

Protocol-state reach is now the strongest surviving feed face.

Why:

- publication/update reach no longer wins clearly enough to stay the default
  contradiction
- runtime is still narrowed to write/wake mechanics
- lock access is still narrowed to the mutex
- the remaining broad named state face on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  is `interaction`

That face still matters because active protocol helpers reach it indirectly
through:

- [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
- [terminal_core_csi_input_modes.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_input_modes.zig)
- [terminal_core_reset.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_reset.zig)

## Exact Pressure

The active contradiction is no longer “generic parser discomfort.”

It is:

- feed execution still carries one broad protocol-state slab
- protocol helpers still depend on that state through session-shaped reach
  rather than a narrower feed-facing protocol-state contract

## Decision

The next default feed-execution front is protocol-state reach unless a
stronger named contradiction overtakes it immediately.

## Design Bar

A protocol-state-only cut did not survive the active call graph cleanly.

Why it failed:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
  still mutates and republishes protocol mode state through full
  `session.interaction` reach when called from active CSI paths
- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  still uses host-contract state for reporting/runtime hooks
- kitty placement/runtime-adjacent helpers still read host-contract cell
  metrics on the same receiver shape

Current judgment:

- the next honest move is not to pretend `interaction` can already disappear
- the next honest move is to split one narrower feed-facing protocol-state
  contract that survives those real dependencies

## Progress

The first survivable split is now landed.

What changed:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  no longer carries one raw `interaction` face
- the active feed receiver now carries explicit state faces instead:
  - `protocol_modes`
  - `derived_snapshot`
  - `host_contract`
- [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
  now resolves protocol-mode and derived-snapshot access through those
  explicit faces instead of requiring the raw interaction bag
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
  now mutates and republishes input protocol state through that narrower
  protocol-state contract
- [host_reporting.zig](/home/home/personal/zide/src/terminal/core/session/host_reporting.zig)
  and [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  now consume an explicit host-contract face instead of depending on the same
  raw interaction bag
- [placement_ops.zig](/home/home/personal/zide/src/terminal/kitty/placement_ops.zig)
  now reads host cell metrics through that same explicit host-contract face

Current judgment after the split:

- the active feed path no longer depends on a monolithic `interaction` bag
- protocol modes and derived snapshots are now a real narrower contract
- host-contract state still survives, but it survives as a separate explicit
  dependency rather than being smuggled through protocol state
- the next contradiction is therefore narrower than “raw interaction reach”

## Further Progress

The surviving host-contract dependency is now split too.

What changed:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  no longer carries one mixed `host_contract` face
- the active feed receiver now carries two explicit faces instead:
  - reporting contract
  - host metrics
- [host_reporting.zig](/home/home/personal/zide/src/terminal/core/session/host_reporting.zig)
  now consumes those two faces explicitly instead of treating flags, color
  state, and cell metrics as one bag
- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  now reads CSI reply geometry/color from host metrics and resets reporting
  flags through the reporting-contract face
- [placement_ops.zig](/home/home/personal/zide/src/terminal/kitty/placement_ops.zig)
  now reads only host metrics, not a broader host-contract shape

Current judgment after the host split:

- the feed receiver no longer carries one mixed host-contract bag
- the remaining contradiction is narrower again:
  - reporting contract flags
  - or host metrics/color state
- the next move should rerank those two explicitly instead of treating them as
  one surviving face
