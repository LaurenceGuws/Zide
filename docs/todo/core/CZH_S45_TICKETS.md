# `CZH-S45` Tickets — Terminal/widget fold API narrowing + field-shape lock

Sprint: `CZH-S45`  
Authority parent: accepted `CZH-B49` boundary fold-route unification + transport-field contraction  
Super-gate: `CZH-GATE-104`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: API narrowing and field-shape locking only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-991` Fold API/field-shape audit + cut map
### `CZH-992` Authority tightening (`doc-only`)
### `CZH-993` Refresh fold API narrowing
### `CZH-994` Reuse fold API narrowing
### `CZH-995` Direct fold API narrowing
### `CZH-996` Refresh/reuse field-shape lock cut
### `CZH-997` Direct field-shape lock cut
### `CZH-998` Helper-level invariants for narrowed API + locked field shapes
### `CZH-999` Integration invariants + hygiene sweep
### `CZH-1000` Validation packet + gate handoff
