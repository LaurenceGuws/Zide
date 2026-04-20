# `CZH-S46` Tickets — Fold/result struct contraction + boundary callsite collapse

Sprint: `CZH-S46`  
Authority parent: accepted `CZH-B50` fold API narrowing + field-shape lock  
Super-gate: `CZH-GATE-105`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: struct contraction and callsite collapse only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1001` Struct/callsite contraction audit + cut map
### `CZH-1002` Authority tightening (`doc-only`)
### `CZH-1003` Refresh result-struct contraction cut
### `CZH-1004` Reuse result-struct contraction cut
### `CZH-1005` Direct result-struct contraction cut
### `CZH-1006` Widget boundary callsite collapse cut
### `CZH-1007` Terminal boundary callsite collapse cut
### `CZH-1008` Helper-level invariants for contracted struct/callsite surface
### `CZH-1009` Integration invariants + hygiene sweep
### `CZH-1010` Validation packet + gate handoff
