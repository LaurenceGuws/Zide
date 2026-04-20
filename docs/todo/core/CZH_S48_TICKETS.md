# `CZH-S48` Tickets — Canonical fold entry collapse + boundary field route lock

Sprint: `CZH-S48`  
Authority parent: accepted `CZH-B52` outcome/transport helper collapse + boundary callsite canonicalization  
Super-gate: `CZH-GATE-107`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: fold-entry collapse and field-route locking only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1021` Fold-entry/field-route audit + cut map
### `CZH-1022` Authority tightening (`doc-only`)
### `CZH-1023` Refresh canonical fold-entry collapse cut
### `CZH-1024` Reuse canonical fold-entry collapse cut
### `CZH-1025` Direct canonical fold-entry collapse cut
### `CZH-1026` Refresh boundary field-route lock cut
### `CZH-1027` Reuse/direct boundary field-route lock cut
### `CZH-1028` Helper-level invariants for collapsed entries + locked routes
### `CZH-1029` Integration invariants + hygiene sweep
### `CZH-1030` Validation packet + gate handoff
