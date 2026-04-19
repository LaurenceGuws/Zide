# `CZH-S23` Tickets — long-loop present reporting carrier consolidation

Sprint: `CZH-S23`  
Authority parent: accepted conjunction propagation lock (`CZH-B27`)  
Super-gate: `CZH-GATE-82`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-780` unless a real hard blocker appears.

## Ticket list

### `CZH-771` Reporting-carrier audit + hygiene scope

- **Goal:** map present-time conjunction reporting carriers and choose dominant carrier per flow.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Done when:** queue records reporting-carrier map plus `CZH-779` hygiene scope.

### `CZH-772` Tighten docs for reporting-carrier boundaries

- **Goal:** align module/function docs to explicit reporting-carrier ownership.
- **Constraint:** docs/comments only; no logic changes.

### `CZH-773` Normalize runtime reporting carrier naming

- **Goal:** converge selected runtime reporting callsites to the dominant carrier name.
- **Constraint:** preserve behavior.

### `CZH-774` Normalize state/report bridge naming

- **Goal:** align selected state-to-report bridge naming where conjunction is surfaced.
- **Constraint:** preserve behavior.

### `CZH-775` Normalize present-result report wording

- **Goal:** remove remaining report-wording ambiguity between leg and conjunction in selected paths.
- **Constraint:** preserve semantics.

### `CZH-776` Align widget/draw comments with reporting carrier ownership

- **Goal:** remove ambiguous reporting ownership wording in selected widget/draw comments.
- **Constraint:** docs/comments and naming only.

### `CZH-777` Add helper-level reporting-carrier invariant tests

- **Goal:** lock helper-level invariants around dominant reporting carrier boundaries.

### `CZH-778` Add integration reporting-carrier invariant tests

- **Goal:** lock representative integration invariants in selected runtime/report paths.

### `CZH-779` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-780` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S23_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-82`.
