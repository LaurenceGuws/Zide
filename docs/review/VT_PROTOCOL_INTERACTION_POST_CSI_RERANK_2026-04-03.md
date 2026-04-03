# VT Protocol Interaction Post-CSI Rerank

Date: 2026-04-03

## Purpose

Rerank the protocol interaction contract war after the CSI ownership wave.

The question is no longer:

- can we prove `session.interaction` was mixed?

That is already proven and reflected in code.

The question is now:

- is there one more real protocol interaction contradiction left here
- or is this lane now clean enough to stop before deeper parser-owner work

## What Landed

The CSI ownership wave materially changed the interaction story.

Live categories are now explicit in
[interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig):

- `protocol_modes`
- `host_contract`
- `derived_snapshot`

The wave also landed:

- mode/query reads and writes separated across those categories
- reply/report input packaged through
  [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  `Snapshot`
- derived input snapshot state no longer hidden under protocol mode state

## Current Read

The original mixed-state lie is no longer the dominant story.

What now reads substantially cleaner:

- CSI mode mutation
- CSI mode query
- CSI reply/report state assembly
- input/read-side snapshot ownership

What still remains outside core, correctly:

- writer locking
- reply write mechanics
- transport/reporting execution

That means the remaining question is narrower than the war opener.

## Remaining Candidates

### 1. Narrow reporting pockets

This is now the strongest local candidate.

Examples:

- kitty/reporting flags and their adjacent send paths
- any remaining reply/report helper that still teaches a mixed ownership story

Current judgment:

- real, but narrower than the CSI center we just flattened

### 2. Deeper parser-owner work

This is now the stronger structural continuation.

Current judgment:

- parser/protocol execution still cannot move more terminal-centered until the
  deeper owner boundary is cleaner
- but that is no longer the same thing as “CSI interaction state is mixed”

### 3. Keep pushing CSI by momentum

Current judgment:

- not justified
- the remaining CSI-local gains now look thin compared to the work already
  landed

## Conclusion

The protocol interaction contract war materially paid off.

The current honest rerank is:

1. stop treating broad CSI ownership cleanup as the active war
2. only reopen this lane for one narrow reporting pocket if it is clearly real
3. otherwise return to the deeper parser-owner / `TerminalCore` sufficiency
   question from the cleaner baseline

## Bottom Line

This lane is close to a stop-marker.

The big win is already in:

- protocol mode state
- host contract state
- derived snapshot state
- explicit reply/report snapshot state

The next VT move should not be “more CSI.”
It should be either:

- one named narrow reporting pocket
- or the deeper parser-owner maturity question
