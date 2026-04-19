# `CZH-S38` Tickets — Outcome carrier simplification + boundary de-duplication

Sprint: `CZH-S38`  
Authority parent: accepted `CZH-B42` callback surface reduction + boundary hardening  
Super-gate: `CZH-GATE-97`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: carrier simplification and boundary de-duplication only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-921` Carrier-flow audit + de-dup map
- Audit outcome carrier flow across terminal/widget boundary and identify de-duplication targets.

### `CZH-922` Authority tightening (`doc-only`)
- Update authority docs to match simplified carrier ownership and transport.

### `CZH-923` Refresh outcome carrier simplification
- Simplify refresh outcome carrier transport and remove duplicate intermediate hops.

### `CZH-924` Reuse outcome carrier simplification
- Simplify reuse outcome carrier transport and remove duplicate intermediate hops.

### `CZH-925` Direct-present outcome carrier simplification
- Simplify direct-present outcome carrier transport and remove duplicate intermediate hops.

### `CZH-926` Widget/runtime boundary de-dup cut
- Remove redundant boundary glue tied to now-simplified carrier flow.

### `CZH-927` Helper-level invariants
- Add helper tests locking simplified carrier-path semantics.

### `CZH-928` Integration invariants
- Add integration tests locking parity and compatibility after de-duplication.

### `CZH-929` Hygiene sweep
- Remove any probe/debug residue and stale source comment lineage in touched files.

### `CZH-930` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S38_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-97`.
