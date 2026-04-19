# `CZH-S24` Tickets — long-loop reporting/result cohesion lock

Sprint: `CZH-S24`  
Authority parent: accepted reporting-carrier consolidation (`CZH-B28`)  
Super-gate: `CZH-GATE-83`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-790` unless a real hard blocker appears.

## Ticket list

### `CZH-781` Reporting/result cohesion audit + hygiene scope

- **Goal:** map dominant reporting carriers vs present-result fields in selected flows and lock no-overlap boundaries (leg vs conjunction).
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `presentable_contract.zig`, `terminal_widget_presentation_state.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Done when:** queue records carrier/result map plus `CZH-789` hygiene scope.

### `CZH-782` Tighten docs for reporting/result ownership

- **Goal:** align module/function docs to explicit ownership boundaries between reporting carriers and result fields.
- **Constraint:** docs/comments only; no logic changes.

### `CZH-783` Normalize runtime naming around result aggregation

- **Goal:** converge selected runtime naming where conjunction is computed/reported vs where legs are carried.
- **Constraint:** preserve behavior.

### `CZH-784` Normalize state/read bridge naming

- **Goal:** align selected state/read bridge naming so stored legs and reported conjunction remain unambiguous.
- **Constraint:** preserve behavior.

### `CZH-785` Normalize present-result wording

- **Goal:** remove remaining wording ambiguity in selected present-result structs/comments around leg vs conjunction.
- **Constraint:** preserve semantics.

### `CZH-786` Align widget/draw ownership notes

- **Goal:** lock widget/draw comments to ownership boundaries (draw consumes state; runtime computes/updates).
- **Constraint:** docs/comments and naming only.

### `CZH-787` Add helper-level reporting/result invariant tests

- **Goal:** lock helper-level invariants around reporting carrier/result cohesion boundaries.

### `CZH-788` Add integration reporting/result invariant tests

- **Goal:** lock representative integration invariants across runtime/state/result seams.

### `CZH-789` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-790` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S24_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-83`.
