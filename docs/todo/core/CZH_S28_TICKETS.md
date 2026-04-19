# `CZH-S28` Tickets — present/outcome seam hardening implementation cut

Sprint: `CZH-S28`  
Authority parent: accepted runtime/surface contraction cut (`CZH-B32`)  
Super-gate: `CZH-GATE-87`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No empty commits unless the ticket is explicitly tagged `doc-only` or `verification-only`.
- Behavior freeze by default; any behavior fix must be isolated and explicitly declared.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-830` unless a real hard blocker appears.

## Ticket list

### `CZH-821` Hardening audit + scope lock
- Map remaining concrete hardening opportunities in present/outcome seam paths.
- Record exact edit targets and `CZH-829` hygiene scope.

### `CZH-822` Canonical-route doc tightening (`doc-only`)
- Tighten module/function docs for the selected hardening scope.

### `CZH-823` Runtime hardening cut A
- Land first concrete runtime seam hardening edit.

### `CZH-824` Runtime hardening cut B
- Land second concrete runtime seam hardening edit.

### `CZH-825` Surface/read bridge hardening cut
- Land concrete surface/read bridge hardening edit.

### `CZH-826` Present-result fold hardening cut
- Land concrete fold-path hardening edit while preserving leg/conjunction roles.

### `CZH-827` Helper-level hardening invariants
- Add helper tests locking hardening invariants for touched paths.

### `CZH-828` Integration hardening invariants
- Add integration tests locking runtime/state/result behavior for touched flows.

### `CZH-829` Scoped probe/doc hygiene sweep + authority sync
- Remove stale investigation-only probe/debug residue and sync authority wording.
- Record removed/kept signals and rationale.

### `CZH-830` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S28_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-87`.
