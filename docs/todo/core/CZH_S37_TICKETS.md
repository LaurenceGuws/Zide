# `CZH-S37` Tickets — Callback surface reduction + boundary hardening

Sprint: `CZH-S37`  
Authority parent: accepted `CZH-B41` execution-hook purity + facade tightening  
Super-gate: `CZH-GATE-96`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: boundary-hardening and signature reduction only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-911` Boundary audit + reduction map
- Audit callback data flow and identify reducible fields/params on terminal/widget boundary.

### `CZH-912` Authority tightening (`doc-only`)
- Update authority docs so ownership and reduced boundary semantics are explicit.

### `CZH-913` Refresh callback surface reduction
- Reduce refresh callback payload to minimal required integration data.

### `CZH-914` Reuse callback surface reduction
- Reduce reuse callback payload and remove redundant transported context.

### `CZH-915` Direct-present callback surface reduction
- Reduce direct-present callback payload and tighten invocation contract.

### `CZH-916` Widget facade contraction
- Remove duplicated boundary glue and ensure facade-only behavior in widget runtime.

### `CZH-917` Helper-level invariants
- Add terminal-layer invariants for reduced callback contracts.

### `CZH-918` Integration boundary invariants
- Add integration tests locking compatibility and behavior parity after reductions.

### `CZH-919` Hygiene sweep
- Remove any probe/debug residue and stale source comment lineage in touched files.

### `CZH-920` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S37_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-96`.
