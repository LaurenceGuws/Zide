# `CZH-S51` Tickets — Fold transport route pruning + assertion surface minimization

Sprint: `CZH-S51`  
Authority parent: accepted `CZH-B55` fold-route assertion collapse + transport mapping simplification  
Super-gate: `CZH-GATE-110`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: route pruning and assertion-surface minimization only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1051` Route/assertion minimization audit + cut map
### `CZH-1052` Authority tightening (`doc-only`)
### `CZH-1053` Refresh transport route pruning cut
### `CZH-1054` Reuse transport route pruning cut
### `CZH-1055` Direct transport route pruning cut
### `CZH-1056` Refresh assertion-surface minimization cut
### `CZH-1057` Reuse/direct assertion-surface minimization cut
### `CZH-1058` Helper-level invariants for pruned routes + minimal assertions
### `CZH-1059` Integration invariants + hygiene sweep
### `CZH-1060` Validation packet + gate handoff
