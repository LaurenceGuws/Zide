# `CZH-S41` Tickets — Boundary alias pruning + surface contract narrowing

Sprint: `CZH-S41`  
Authority parent: accepted `CZH-B45` refresh/reuse transport boundary consolidation  
Super-gate: `CZH-GATE-100`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: alias pruning and vocabulary narrowing only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-951` Alias/vocabulary audit + pruning map
- Audit boundary alias terms and identify canonical replacements.

### `CZH-952` Authority tightening (`doc-only`)
- Update authority docs to canonical vocabulary and narrowed contract terms.

### `CZH-953` Refresh alias pruning
- Replace refresh-side alias terms with canonical transport vocabulary.

### `CZH-954` Reuse alias pruning
- Replace reuse-side alias terms with canonical transport vocabulary.

### `CZH-955` Direct/fold alias pruning
- Replace direct/fold alias terms with canonical transport vocabulary.

### `CZH-956` Widget/runtime boundary cleanup
- Remove stale boundary alias glue after term narrowing.

### `CZH-957` Helper-level invariants
- Add helper tests locking canonical vocabulary routes and behavior parity.

### `CZH-958` Integration invariants
- Add integration tests locking boundary compatibility after alias pruning.

### `CZH-959` Hygiene sweep
- Remove probe/debug residue and stale source comment lineage in touched files.

### `CZH-960` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S41_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-100`.
