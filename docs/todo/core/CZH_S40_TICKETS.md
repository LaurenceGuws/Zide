# `CZH-S40` Tickets — Refresh/reuse transport boundary consolidation

Sprint: `CZH-S40`  
Authority parent: accepted `CZH-B44` result transport flattening + contract locking  
Super-gate: `CZH-GATE-99`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: transport boundary consolidation only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-941` Transport boundary audit + consolidation map
- Audit remaining refresh/reuse boundary spread and identify consolidation cuts.

### `CZH-942` Authority tightening (`doc-only`)
- Update authority docs to match consolidated boundary ownership.

### `CZH-943` Refresh transport boundary consolidation
- Consolidate refresh transport boundaries into terminal-owned canonical path.

### `CZH-944` Reuse transport boundary consolidation
- Consolidate reuse transport boundaries into terminal-owned canonical path.

### `CZH-945` Boundary helper simplification
- Simplify helper boundaries after consolidation without behavior change.

### `CZH-946` Widget/runtime boundary cleanup
- Remove redundant integration glue left after consolidation.

### `CZH-947` Helper-level invariants
- Add helper tests locking consolidated refresh/reuse transport semantics.

### `CZH-948` Integration invariants
- Add integration tests locking parity and compatibility after consolidation.

### `CZH-949` Hygiene sweep
- Remove probe/debug residue and stale source comment lineage in touched files.

### `CZH-950` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S40_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-99`.
