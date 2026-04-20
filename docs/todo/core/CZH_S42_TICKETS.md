# `CZH-S42` Tickets — Boundary helper contraction + refresh/reuse result narrowing

Sprint: `CZH-S42`  
Authority parent: accepted `CZH-B46` boundary alias pruning + surface contract narrowing  
Super-gate: `CZH-GATE-101`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: helper contraction and boundary/result narrowing only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-961` Boundary helper contraction audit + cut map
- Audit remaining refresh/reuse helper wrappers and duplicate fold/result transports.

### `CZH-962` Authority tightening (`doc-only`)
- Update authority docs to the narrowed helper/result boundary story.

### `CZH-963` Refresh helper contraction
- Remove refresh-side wrapper duplication and keep one canonical terminal fold helper route.

### `CZH-964` Reuse helper contraction
- Remove reuse-side wrapper duplication and keep one canonical terminal fold helper route.

### `CZH-965` Refresh boundary result narrowing
- Narrow refresh boundary carrier fields to canonical host-facing folded result semantics.

### `CZH-966` Reuse boundary result narrowing
- Narrow reuse boundary carrier fields to canonical host-facing folded result semantics.

### `CZH-967` Widget/runtime boundary cleanup
- Remove stale boundary glue and redundant local mappings after helper/result contraction.

### `CZH-968` Helper-level invariants
- Add helper tests locking canonical helper routes and narrowed result-carrying semantics.

### `CZH-969` Integration invariants + hygiene sweep
- Add integration tests for boundary parity and sweep touched files for probe/comment hygiene.

### `CZH-970` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S42_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-101`.
