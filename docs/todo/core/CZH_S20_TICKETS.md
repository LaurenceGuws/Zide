# `CZH-S20` Tickets — long-loop surface contract alias reduction

Sprint: `CZH-S20`  
Authority parent: accepted observability vocabulary lock (`CZH-B24`)  
Super-gate: `CZH-GATE-79`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-750` unless a real hard blocker appears.

## Ticket list

### `CZH-741` Alias inventory audit + hygiene scope

- **Goal:** map remaining alias pairs in selected paths and choose canonical terms.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_draw.zig`, `terminal_widget.zig`, `surface_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** queue records alias map plus `CZH-749` hygiene scope.

### `CZH-742` Tighten seam docs to one canonical term per concept

- **Goal:** align module/function docs with canonical terms from `CZH-741`.
- **Constraint:** docs/comments only; no logic changes.

### `CZH-743` Converge generation-owned alias sites

- **Goal:** reduce duplicate terms for generation state in selected touched runtime/state paths.
- **Constraint:** no behavior changes.

### `CZH-744` Converge pipeline-leg alias sites

- **Goal:** reduce duplicate terms for pipeline readiness in selected touched paths.
- **Constraint:** preserve semantics.

### `CZH-745` Converge host-target/full-attachment alias sites

- **Goal:** reduce duplicate terms for host target and full attachment in selected touched paths.
- **Constraint:** preserve semantics.

### `CZH-746` Converge widget/draw string aliases

- **Goal:** align selected widget/draw log and local variable vocabulary with canonical terms.
- **Constraint:** keep operator telemetry value semantics unchanged.

### `CZH-747` Add seam helper invariants for alias reduction

- **Goal:** lock helper-level invariants that canonical names still map to unchanged predicates.

### `CZH-748` Add runtime/widget integration invariants for alias reduction

- **Goal:** lock representative integration invariants across selected touched paths.

### `CZH-749` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-750` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S20_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-79`.
