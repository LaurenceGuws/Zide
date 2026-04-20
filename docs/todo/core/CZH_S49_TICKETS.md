# `CZH-S49` Tickets — Fold transport helper collapse + route-lock simplification

Sprint: `CZH-S49`  
Authority parent: accepted `CZH-B53` canonical fold-entry collapse + boundary field-route lock  
Super-gate: `CZH-GATE-108`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: helper collapse and route-lock simplification only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1031` Helper/route-lock simplification audit + cut map
### `CZH-1032` Authority tightening (`doc-only`)
### `CZH-1033` Refresh transport-helper collapse cut
### `CZH-1034` Reuse transport-helper collapse cut
### `CZH-1035` Direct transport-helper collapse cut
### `CZH-1036` Refresh route-lock simplification cut
### `CZH-1037` Reuse/direct route-lock simplification cut
### `CZH-1038` Helper-level invariants for collapsed helpers + simplified locks
### `CZH-1039` Integration invariants + hygiene sweep
### `CZH-1040` Validation packet + gate handoff
