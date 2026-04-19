# `CZH-S16` Tickets — long-loop generation-vs-attachment seam convergence

Sprint: `CZH-S16`  
Authority parent: accepted host-attachment seam pack (`CZH-B20`)  
Super-gate: `CZH-GATE-75`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-710` unless a real hard
  blocker appears.

## Ticket list

### `CZH-701` Audit seam ownership + scoped hygiene

- **Goal:** map selected generation-vs-attachment call sites and naming drift
  in touched modules before edits.
- **Targets:** `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`, `terminal_widget_draw.zig`,
  `surface_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** implementation queue records classified touchpoints and
  hygiene scope.

### `CZH-702` Add naming-safe helper aliases/docs (no semantic change)

- **Goal:** tighten naming/docs so generation ownership and attachment
  ownership are unambiguous at the seam.
- **Constraint:** helper/doc additions only.

### `CZH-703` Converge selected presentation-runtime generation checks

- **Goal:** route selected generation checks through explicit
  `surface_contract` helpers only.
- **Constraint:** no reuse policy behavior change.

### `CZH-704` Converge selected presentation-runtime attachment checks

- **Goal:** route selected attachment checks through explicit
  `surface_attachment_contract` helpers only.
- **Constraint:** no presentability behavior change.

### `CZH-705` Converge selected widget surface-state call sites

- **Goal:** align selected `terminal_widget_surface_state` callers/getters to
  explicit generation vs attachment seam ownership.
- **Constraint:** no semantic changes.

### `CZH-706` Converge selected draw/runtime call sites

- **Goal:** align selected `terminal_widget_draw` touched paths/tests with the
  same seam ownership split.
- **Constraint:** no rendering behavior changes.

### `CZH-707` Add seam invariants tests (contract modules)

- **Goal:** lock primitive/composite invariants for generation + attachment
  seam helpers.

### `CZH-708` Add integration invariants tests (widget/runtime)

- **Goal:** lock selected call-site integration invariants for the converged
  ownership split.

### `CZH-709` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files
  and align authority wording to landed code.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-710` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S16_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-75`.
