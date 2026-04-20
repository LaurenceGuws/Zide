# `CZH-S50` Tickets — Fold-route assertion collapse + transport mapping simplification

Sprint: `CZH-S50`  
Authority parent: accepted `CZH-B54` fold transport helper collapse + route-lock simplification  
Super-gate: `CZH-GATE-109`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: assertion collapse and mapping simplification only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1041` Assertion/mapping simplification audit + cut map
### `CZH-1042` Authority tightening (`doc-only`)
### `CZH-1043` Refresh fold-route assertion collapse cut
### `CZH-1044` Reuse fold-route assertion collapse cut
### `CZH-1045` Direct fold-route assertion collapse cut
### `CZH-1046` Refresh transport mapping simplification cut
### `CZH-1047` Reuse/direct transport mapping simplification cut
### `CZH-1048` Helper-level invariants for collapsed assertions + simplified mappings
### `CZH-1049` Integration invariants + hygiene sweep
### `CZH-1050` Validation packet + gate handoff
