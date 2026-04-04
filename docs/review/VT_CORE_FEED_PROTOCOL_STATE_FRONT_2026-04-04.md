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
