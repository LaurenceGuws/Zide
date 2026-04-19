# `CZH-S17` Tickets — long-loop naming/state convergence for generation vs attachment seams

Sprint: `CZH-S17`  
Authority parent: accepted seam convergence pack (`CZH-B21`)  
Super-gate: `CZH-GATE-76`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-720` unless a real hard blocker appears.

## Ticket list

### `CZH-711` Audit naming/state ownership drift + hygiene scope

- **Goal:** map selected drift where pipeline-ready, full attachment-ready, and generation state names are mixed/ambiguous.
- **Targets:** `terminal_widget_presentation_state.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_runtime.zig`, `surface_attachment_contract.zig`, `surface_contract.zig`.
- **Done when:** implementation queue records classified touchpoints and `CZH-719` hygiene scope.

### `CZH-712` Tighten seam doc strings for pipeline vs attachment naming

- **Goal:** sharpen module/struct/field docs to encode explicit ownership of each readiness concept.
- **Constraint:** docs-only ownership tightening; no logic changes.

### `CZH-713` Converge selected runtime naming at generation-owned checks

- **Goal:** align selected generation-check variable names/callsites to `surface_contract` ownership terms.
- **Constraint:** no behavior changes.

### `CZH-714` Converge selected runtime naming at attachment-owned checks

- **Goal:** align selected attachment-readiness variable names/callsites to `surface_attachment_contract` ownership terms.
- **Constraint:** no behavior changes.

### `CZH-715` Converge selected surface-state naming

- **Goal:** align selected `TerminalWidgetSurfaceState` naming so pipeline leg and full attachment conjunction are clearly separated.
- **Constraint:** preserve existing semantics and call flows.

### `CZH-716` Converge selected draw/presentation naming touchpoints

- **Goal:** align selected draw/presentation naming touchpoints to the same seam vocabulary.
- **Constraint:** no rendering/present behavior change.

### `CZH-717` Add seam invariants tests for naming/state split

- **Goal:** lock helper-level invariants for pipeline leg vs full attachment conjunction vs generation mismatch.

### `CZH-718` Add widget/runtime integration invariants for naming split

- **Goal:** lock selected integration invariants ensuring naming split maps to unchanged behavior.

### `CZH-719` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-720` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S17_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-76`.
