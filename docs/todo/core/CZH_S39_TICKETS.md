# `CZH-S39` Tickets — Result transport flattening + contract locking

Sprint: `CZH-S39`  
Authority parent: accepted `CZH-B43` outcome carrier simplification + boundary de-duplication  
Super-gate: `CZH-GATE-98`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: transport flattening + contract locking only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-931` Transport audit + flattening map
- Audit remaining result transport indirections and identify flattening targets.

### `CZH-932` Authority tightening (`doc-only`)
- Update authority docs for flattened transport and contract edges.

### `CZH-933` Refresh transport flattening
- Flatten refresh result transport indirections while preserving semantics.

### `CZH-934` Reuse transport flattening
- Flatten reuse result transport indirections while preserving semantics.

### `CZH-935` Direct-present transport flattening
- Flatten direct-present result transport indirections while preserving semantics.

### `CZH-936` Widget/runtime boundary cleanup
- Remove redundant boundary transport glue after flattening.

### `CZH-937` Helper-level invariants
- Add helper tests locking flattened transport semantics.

### `CZH-938` Integration invariants
- Add integration tests locking boundary compatibility and parity after flattening.

### `CZH-939` Hygiene sweep
- Remove probe/debug residue and stale source comment lineage in touched files.

### `CZH-940` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S39_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-98`.
