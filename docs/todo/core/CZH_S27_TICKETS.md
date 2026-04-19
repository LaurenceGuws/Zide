# `CZH-S27` Tickets — runtime/surface seam contraction implementation cut

Sprint: `CZH-S27`  
Authority parent: accepted surface/result follow-through (`CZH-B31`)  
Super-gate: `CZH-GATE-86`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No empty commits unless the ticket is explicitly tagged `doc-only` or `verification-only`.
- Behavior freeze by default; any behavior fix must be isolated and explicitly declared.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-820` unless a real hard blocker appears.

## Ticket list

### `CZH-811` Runtime/surface contraction audit + scope lock
- Map remaining concrete contraction opportunities that require code edits (not just verification).
- Record exact edit targets and `CZH-819` hygiene scope in queue.

### `CZH-812` Tighten canonical-route docs (`doc-only`)
- Align docs/comments to the exact routes selected in `CZH-811`.

### `CZH-813` Runtime contraction cut A
- Implement first concrete contraction in runtime callsites.
- Preserve behavior.

### `CZH-814` Runtime contraction cut B
- Implement second concrete contraction in runtime callsites.
- Preserve behavior.

### `CZH-815` Surface-state/read bridge contraction cut
- Implement concrete bridge-path contraction in surface-state layer.
- Preserve behavior.

### `CZH-816` Present-result fold contraction cut
- Implement concrete fold-path contraction while preserving leg/conjunction roles.
- Preserve behavior and ABI.

### `CZH-817` Helper-level invariants for landed contractions
- Add helper tests covering touched contraction paths.

### `CZH-818` Integration invariants for landed contractions
- Add integration tests for runtime/state/result cohesion after contractions.

### `CZH-819` Scoped probe/doc hygiene sweep + authority sync
- Remove stale investigation-only probe/debug residue and sync authority wording.
- Record removed/kept signals and rationale.

### `CZH-820` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S27_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-86`.
