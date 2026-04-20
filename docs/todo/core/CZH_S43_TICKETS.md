# `CZH-S43` Tickets — Boundary result transport collapse + helper surface narrowing

Sprint: `CZH-S43`  
Authority parent: accepted `CZH-B47` boundary helper contraction + refresh/reuse result narrowing  
Super-gate: `CZH-GATE-102`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: transport collapse and helper-surface narrowing only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-971` Boundary transport collapse audit + cut map
### `CZH-972` Authority tightening (`doc-only`)
### `CZH-973` Refresh transport collapse cut
### `CZH-974` Reuse transport collapse cut
### `CZH-975` Direct-present transport collapse cut
### `CZH-976` Helper surface narrowing (remove duplicate aliases/wrappers)
### `CZH-977` Widget/runtime boundary cleanup after collapse
### `CZH-978` Helper-level invariants for collapsed transport
### `CZH-979` Integration invariants + hygiene sweep
### `CZH-980` Validation packet + gate handoff
