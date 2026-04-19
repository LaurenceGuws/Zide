# `CZH-S12` Tickets — long-loop surface contract pack + hygiene sweep

Sprint: `CZH-S12`  
Authority parent: accepted `presentationUpdateDelta` seam expansion (`CZH-B16`)  
Super-gate: `CZH-GATE-71`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.
- No early architect bounce: continue through `CZH-670` unless a real hard
  blocker appears.

## Ticket list

### `CZH-661` Audit multi-consumer seam + scoped hygiene targets

- **Goal:** freeze one longer-cut plan (two seam consumers + one hygiene sweep)
  before code edits.
- **Targets:** `surface_contract.zig`,
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`.
- **Done when:** `implementation.md` records the selected consumer cuts and
  scoped hygiene targets.

### `CZH-662` Add composite generation-pair seam helper(s)

- **Goal:** extend `surface_contract.zig` with small composite helpers that name
  generation+clear-generation pairing for widget draw/presentation consumers.
- **Constraint:** helper-only and behavior-neutral.
- **Done when:** helper(s) compile with concise ownership docs.

### `CZH-663` Route present-plan generation-matches conjunct via composite helper

- **Goal:** in `terminal_widget_presentation_runtime.zig`, route
  `generation_matches_presented` ownership through the new composite seam
  helper(s).
- **Constraint:** no draw-policy changes.
- **Done when:** behavior-equivalent wiring lands.

### `CZH-664` Route presentationUpdateDelta fields via composite helper

- **Goal:** in `terminal_widget_surface_state.zig`, route
  `generation_changed`/`clear_generation_changed` ownership through composite
  seam helper(s) where appropriate.
- **Constraint:** no behavior changes.
- **Done when:** behavior-equivalent wiring lands.

### `CZH-665` Tighten seam docs at code boundary

- **Goal:** ensure function/module docs in touched modules describe ownership
  truth after `CZH-662`..`CZH-664`.
- **Done when:** docs are aligned and non-duplicative.

### `CZH-666` Add focused seam invariants tests (part 1)

- **Goal:** add unit tests for composite helper invariants in
  `surface_contract.zig`.
- **Done when:** tests prove equivalence with prior predicate logic.

### `CZH-667` Add focused seam invariants tests (part 2)

- **Goal:** extend/adjust call-site level tests (where present) so the new seam
  ownership is regression-locked.
- **Done when:** target tests compile and pass.

### `CZH-668` Scoped probe/debug residue sweep in touched files

- **Goal:** remove stale investigation-only debug/probe caller residue in files
  touched by this sprint; keep required operator/error logs only.
- **Done when:** queue note records what was removed/kept and why.

### `CZH-669` Authority/doc sync for landed terms

- **Goal:** sync `TERMINAL_SURFACE_CONTRACT.md` and queue landed notes to code
  truth only.
- **Done when:** no planned-only wording remains for landed cuts.

### `CZH-670` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S12_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-71`.
