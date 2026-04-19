# `CZH-S9` Tickets — surface contract consumer expansion

Sprint: `CZH-S9`  
Authority parent: accepted presentAck seam expansion (`CZH-B13`)  
Super-gate: `CZH-GATE-68`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.

## Ticket list

### `CZH-646` Audit next draw/presentation-facing seam consumer

- **Goal:** identify one bounded draw/presentation-facing path where generation
  ownership is still implicit and should consume explicit `surface_contract`
  seam naming.
- **Minimum targets:** `src/terminal/surface_contract.zig` and one selected
  terminal draw/presentation path from `src/ui/widgets/terminal_widget*`.
- **Done when:** `implementation.md` records the selected path and a
  no-behavior-change seam-cut plan.

### `CZH-647` Add minimal seam helper/type for selected path

- **Goal:** extend `surface_contract.zig` with only the helper/type needed by
  the selected path.
- **Constraint:** helper-only and behavior-neutral.
- **Done when:** helper/type compiles with concise ownership docs.

### `CZH-648` Route selected path through seam helper/type

- **Goal:** land one behavior-neutral wiring cut in the selected path.
- **Constraint:** no draw policy changes, no ABI changes.
- **Done when:** selected path uses seam helper/type and runtime behavior is
  equivalent.

### `CZH-649` Add/update focused assertions and sync authority notes

- **Goal:** add assertions for seam invariants in the selected path and align
  queue/authority wording to landed code.
- **Files:** selected test file(s), `docs/todo/core/implementation.md`, and
  `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` only where wording
  must reflect landed terms.
- **Done when:** tests/assertions cover the seam cut and docs no longer describe
  the path as planned-only.

### `CZH-650` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S9_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-68`.
