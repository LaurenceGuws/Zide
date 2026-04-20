# `CZH-S47` Tickets — Outcome/transport helper collapse + callsite canonicalization

Sprint: `CZH-S47`  
Authority parent: accepted `CZH-B51` fold/result struct contraction + boundary callsite collapse  
Super-gate: `CZH-GATE-106`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: helper collapse and callsite canonicalization only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1011` Helper/callsite collapse audit + cut map
### `CZH-1012` Authority tightening (`doc-only`)
### `CZH-1013` Refresh helper collapse cut
### `CZH-1014` Reuse helper collapse cut
### `CZH-1015` Direct helper collapse cut
### `CZH-1016` Widget callsite canonicalization cut
### `CZH-1017` Terminal callsite canonicalization cut
### `CZH-1018` Helper-level invariants for collapsed helper surface
### `CZH-1019` Integration invariants + hygiene sweep
### `CZH-1020` Validation packet + gate handoff
