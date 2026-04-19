# `CZH-S14` Tickets — long-loop surface/FFI convergence pack

Sprint: `CZH-S14`  
Authority parent: accepted VT FFI seam wrapper pack (`CZH-B18`)  
Super-gate: `CZH-GATE-73`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.
- No early architect bounce: continue through `CZH-690` unless a real hard
  blocker appears.

## Ticket list

### `CZH-681` Audit convergence targets + scoped hygiene

- **Goal:** freeze one longer-cut plan for converging selected mixed
  primitive/composite/ffi seam consumers before code edits.
- **Targets:** `surface_contract.zig`, `terminal_widget_surface_state.zig`,
  `core_api.zig`.
- **Done when:** `implementation.md` records selected convergence cuts and
  hygiene scope.

### `CZH-682` Clarify seam helper layering docs in surface_contract

- **Goal:** tighten helper-layer ownership docs (primitive vs composite vs ffi
  wrappers) with no semantic changes.
- **Done when:** docs are concise and non-overlapping.

### `CZH-683` Converge selected widget seam call sites/tests (part 1)

- **Goal:** route selected widget seam consumers/tests to one explicit ownership
  shape per contract (primitive/composite as chosen in `CZH-681`).
- **Constraint:** no behavior change.

### `CZH-684` Converge selected widget seam call sites/tests (part 2)

- **Goal:** complete widget convergence from `CZH-683` and remove local seam
  shape drift in touched paths.
- **Constraint:** no behavior change.

### `CZH-685` Converge selected core_api seam tests/docs (part 1)

- **Goal:** align selected `core_api` seam tests/docs with the explicit ffi
  wrapper ownership shape.
- **Constraint:** no ABI/behavior changes.

### `CZH-686` Converge selected core_api seam tests/docs (part 2)

- **Goal:** complete `core_api` convergence and remove remaining drift in
  touched seam tests/docs.
- **Constraint:** no ABI/behavior changes.

### `CZH-687` Add focused convergence invariants tests (surface_contract)

- **Goal:** lock helper-layer equivalence/invariants for the landed convergence
  shape in `surface_contract.zig`.

### `CZH-688` Add focused convergence invariants tests (widget/core_api)

- **Goal:** lock call-site integration invariants in the selected widget and
  ffi/core_api touched paths.

### `CZH-689` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files
  and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals and rationale.

### `CZH-690` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S14_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-73`.
