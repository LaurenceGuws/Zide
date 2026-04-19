# `CZH-S7` Tickets — terminal surface contract wiring seed

Sprint: `CZH-S7`  
Authority parent: accepted FFI debug-hook removal sprint (`CZH-B11`)  
Super-gate: `CZH-GATE-66`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.

## Ticket list

### `CZH-636` Audit terminal surface ownership touchpoints

- **Goal:** map current surface ownership/wiring where host bind/present and
  Zide dirty/update responsibilities currently cross.
- **Minimum targets:** terminal renderer/runtime surface entry seams and
  references from `TERMINAL_SURFACE_CONTRACT.md`.
- **Done when:** `implementation.md` has an explicit touchpoint map and bounded
  first-cut seam plan.

### `CZH-637` Introduce explicit shared-surface seam types/helpers

- **Goal:** add explicit code-level seam names for the accepted terminal surface
  contract.
- **Constraint:** behavior-neutral; no ABI/export change.
- **Done when:** the new seam types/helpers exist and compile, with concise
  ownership docs.

### `CZH-638` Land one behavior-neutral wiring cut through the new seam

- **Goal:** use the seam in one bounded wiring path so the new contract is not
  dead scaffolding.
- **Constraint:** no runtime behavior change; no renderer policy change.
- **Done when:** one path reads/writes through the new seam type/helper and
  tests/builds stay green.

### `CZH-639` Sync queue/authority docs to post-cut truth

- **Goal:** align queue and architecture docs with the landed seam names and
  wiring path.
- **Files:** at minimum `docs/todo/core/implementation.md`; update
  `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` only where wording
  must reflect landed code terms.
- **Done when:** docs no longer describe the seam as planned-only for that path.

### `CZH-640` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S7_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-66`.
