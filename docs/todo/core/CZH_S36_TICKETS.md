# `CZH-S36` Tickets — Execution-hook purity and facade tightening

Sprint: `CZH-S36`  
Authority parent: accepted `CZH-B40` callback-based orchestration extraction  
Super-gate: `CZH-GATE-95`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: ownership tightening and invariant hardening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-901` Seam audit + map
- Audit remaining callback execution-hook ambiguity between terminal and widget runtime.
- Produce explicit map of ownership for decision, folding, and side-effect hooks.

### `CZH-902` Authority tightening (`doc-only`)
- Update authority docs so ownership language matches `CZH-B40` landed code and `CZH-S36` scope.

### `CZH-903` Refresh hook signature tightening
- Reduce refresh hook surface to minimal data needed by terminal orchestrator.

### `CZH-904` Reuse/direct hook signature tightening
- Tighten reuse and direct-present callback interfaces to remove redundant parameters.

### `CZH-905` Widget facade contraction
- Remove any duplicated glue that mirrors terminal-owned decisions or folds.

### `CZH-906` Comment and docstring normalization
- Ensure touched source comments describe only current ownership/invariants.

### `CZH-907` Helper-level invariants
- Add terminal-layer tests locking tightened hook behavior and parity.

### `CZH-908` Integration invariants
- Add widget/terminal integration tests locking callback boundary compatibility.

### `CZH-909` Hygiene sweep
- Probe/debug residue sweep across touched files; remove non-contract leftovers.

### `CZH-910` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S36_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-95`.
