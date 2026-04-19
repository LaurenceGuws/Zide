# `CZH-S22` Tickets — long-loop present readiness conjunction propagation

Sprint: `CZH-S22`  
Authority parent: accepted present-result ownership lock (`CZH-B26`)  
Super-gate: `CZH-GATE-81`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-770` unless a real hard blocker appears.

## Ticket list

### `CZH-761` Conjunction propagation audit + hygiene scope

- **Goal:** map compute/store/report ownership for full-attachment conjunction in selected present/runtime/state paths.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** queue records phase ownership map plus `CZH-769` hygiene scope.

### `CZH-762` Tighten docs for compute/store/report boundaries

- **Goal:** align module/function docs to explicit conjunction propagation boundaries.
- **Constraint:** docs/comments only; no logic changes.

### `CZH-763` Normalize compute-site naming for full attachment

- **Goal:** ensure conjunction compute-site locals use one canonical term in selected runtime paths.
- **Constraint:** preserve behavior.

### `CZH-764` Normalize storage-site naming for full attachment

- **Goal:** ensure selected state/result carriers store conjunction under explicit canonical naming.
- **Constraint:** preserve behavior.

### `CZH-765` Normalize report-site naming for full attachment

- **Goal:** ensure selected report/log/result paths use explicit conjunction naming and avoid leg/conjunction ambiguity.
- **Constraint:** preserve semantics.

### `CZH-766` Align widget/draw comments with propagation boundaries

- **Goal:** remove ambiguous wording around leg vs conjunction ownership in selected widget/draw comments.
- **Constraint:** docs/comments and naming only.

### `CZH-767` Add helper-level propagation invariant tests

- **Goal:** lock helper-level invariants for compute/store/report separation.

### `CZH-768` Add integration propagation invariant tests

- **Goal:** lock representative integration invariants where conjunction flows through result/state/report paths.

### `CZH-769` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-770` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S22_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-81`.
