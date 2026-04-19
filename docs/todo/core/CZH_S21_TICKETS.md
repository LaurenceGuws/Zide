# `CZH-S21` Tickets — long-loop present result ownership lock

Sprint: `CZH-S21`  
Authority parent: accepted alias reduction (`CZH-B25`)  
Super-gate: `CZH-GATE-80`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-760` unless a real hard blocker appears.

## Ticket list

### `CZH-751` Present result ownership audit + hygiene scope

- **Goal:** map host-target leg vs full-attachment ownership in selected present/runtime/state paths.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** queue records ownership map plus `CZH-759` hygiene scope.

### `CZH-752` Tighten ownership docs for host-target vs full-attachment

- **Goal:** align module/function docs to explicit ownership boundaries.
- **Constraint:** docs/comments only; no logic changes.

### `CZH-753` Normalize host-target leg carriers

- **Goal:** ensure selected result/state structs that represent host target carry only host-target signal.
- **Constraint:** preserve behavior.

### `CZH-754` Normalize full-attachment carriers

- **Goal:** ensure selected result/state values that represent full attachment are explicitly distinct from host-target leg.
- **Constraint:** preserve behavior.

### `CZH-755` Align local variable naming to ownership boundaries

- **Goal:** reduce ambiguous names in selected runtime paths where both leg values coexist.
- **Constraint:** preserve semantics.

### `CZH-756` Align widget/draw runtime comments with ownership boundaries

- **Goal:** remove remaining ambiguous wording in selected widget/draw comments.
- **Constraint:** docs/comments and naming only.

### `CZH-757` Add helper-level ownership invariant tests

- **Goal:** lock helper-level invariants for host-target vs full-attachment separation.

### `CZH-758` Add runtime integration ownership invariant tests

- **Goal:** lock representative integration invariants where both signals are carried.

### `CZH-759` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-760` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S21_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-80`.
