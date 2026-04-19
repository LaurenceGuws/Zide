# `CZH-S4` Tickets — extract BYO-PTY out of `terminal/ffi`

Sprint: `CZH-S4`  
Authority parent: accepted split freeze (`CZH-B6`) + explicit BYO packaging sprint (`CZH-B8`)  
Super-gate: `CZH-GATE-63`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes unless a ticket explicitly says so.
- No exported C symbol churn in this sprint.

## Ticket list

### `CZH-621` Audit exact extraction touchpoints

- **Goal:** record the precise imports, paths, and doc references required to
  move the BYO-PTY seam out of `src/terminal/ffi/`.
- **Done when:** `implementation.md` has the bounded extraction map and any
  atomic-move note.

### `CZH-622` Move BYO-PTY module out of `src/terminal/ffi/`

- **Goal:** place the optional BYO-PTY seam under a non-FFI-owned path.
- **Constraint:** no behavior change; bridge remains the external Zig-facing
  join point.
- **Done when:** `bridge.zig` imports the new location and the old path is gone.

### `CZH-623` Align local ownership names and comments after extraction

- **Goal:** make bridge/local wording honest after `CZH-622`.
- **Scope:** import names, module docs, and nearby comments only.
- **Done when:** no local text implies the seam still belongs to `terminal/ffi`.

### `CZH-624` Sync authority docs and inventory to the real placement

- **Goal:** update architecture docs, queue maps, and inventory tables for the
  post-extraction state.
- **Done when:** docs describe the real placement and no longer describe it as
  a packaging smell.

### `CZH-625` Validation packet + gate handoff

- Record ladder results in `implementation.md`.
- Submit `docs/todo/core/CZH_S4_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-63`.
