# `CZH-S8` Tickets — surface contract wiring expansion

Sprint: `CZH-S8`  
Authority parent: accepted surface-contract seam seed (`CZH-B12`)  
Super-gate: `CZH-GATE-67`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.

## Ticket list

### `CZH-641` Audit next bounded surface-contract crossing

- **Goal:** identify one additional concrete path where surface ownership is
  currently implicit and should route through explicit seam naming.
- **Minimum targets:** `src/terminal/surface_contract.zig`,
  `src/terminal/ffi/core_api.zig`, and one downstream terminal draw/presentation
  path selected by the audit.
- **Done when:** `implementation.md` records the selected path and a bounded
  no-behavior-change seam cut plan.

### `CZH-642` Add minimal seam helper(s) for selected path

- **Goal:** extend `surface_contract.zig` with the minimal helper/type needed by
  the selected path.
- **Constraint:** helper-only and behavior-neutral.
- **Done when:** helper/type compiles with concise ownership docs.

### `CZH-643` Route selected path through seam helper(s)

- **Goal:** land one behavior-neutral wiring cut using the new helper(s).
- **Constraint:** no policy changes; no ABI changes.
- **Done when:** selected path uses seam helper(s) and outputs are equivalent.

### `CZH-644` Add/update focused assertions and sync authority notes

- **Goal:** cover seam invariants for the expanded path and sync queue/authority
  wording to landed code.
- **Files:** `tests/tests_main.zig` imports if needed, touched test file(s),
  `docs/todo/core/implementation.md`, and `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
  only if wording must reflect landed code terms.
- **Done when:** assertions are in place and docs no longer describe the path as
  planned-only.

### `CZH-645` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S8_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-67`.
