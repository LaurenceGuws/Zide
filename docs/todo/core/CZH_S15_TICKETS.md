# `CZH-S15` Tickets — long-loop surface attachment contract shaping

Sprint: `CZH-S15`  
Authority parent: accepted layered surface/ffi convergence (`CZH-B19`)  
Super-gate: `CZH-GATE-74`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-700` unless a real hard
  blocker appears.

## Ticket list

### `CZH-691` Audit host-surface attachment seam + scoped hygiene

- **Goal:** map current host-shared-surface attachment touchpoints and lock the
  cut plan before edits.
- **Targets:** `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`, `terminal_widget_draw.zig`,
  `surface_contract.zig`.
- **Done when:** implementation queue records seam cut list and hygiene scope.

### `CZH-692` Add `surface_attachment_contract.zig` primitive helpers

- **Goal:** introduce one Zig seam module naming shared-surface attachment
  primitives/invariants (no behavior change).
- **Constraint:** helpers only; no call-site rewiring yet.

### `CZH-693` Add composite helpers for attachment-state comparisons

- **Goal:** add composite helpers that express attachment-delta shape used by
  widget/presentation consumers.
- **Constraint:** behavior-neutral decomposition.

### `CZH-694` Route selected present-plan seam consumers through attachment helpers

- **Goal:** converge selected present-plan generation/attachment checks in
  `terminal_widget_presentation_runtime.zig` onto the new seam helpers.
- **Constraint:** no present-plan semantic changes.

### `CZH-695` Route selected widget-surface seam consumers through attachment helpers

- **Goal:** converge selected `terminal_widget_surface_state.zig` consumers onto
  the same seam shape.
- **Constraint:** no semantic/ABI changes.

### `CZH-696` Route selected draw/runtime seam consumers through attachment helpers

- **Goal:** converge selected `terminal_widget_draw.zig` touched paths where
  attachment state is compared/derived.
- **Constraint:** no rendering behavior change.

### `CZH-697` Add seam equivalence tests in `surface_attachment_contract.zig`

- **Goal:** lock primitive/composite equivalence and mismatch invariants.

### `CZH-698` Add widget/runtime integration invariants for attachment seam

- **Goal:** lock selected call-site integration invariants in widget/runtime
  touched paths.

### `CZH-699` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files
  and sync authority docs to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-700` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S15_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-74`.
