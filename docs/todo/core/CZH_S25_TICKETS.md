# `CZH-S25` Tickets — long-loop reporting/result seam contraction

Sprint: `CZH-S25`  
Authority parent: accepted reporting/result cohesion lock (`CZH-B29`)  
Super-gate: `CZH-GATE-84`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-800` unless a real hard blocker appears.

## Ticket list

### `CZH-791` Seam-contraction audit + hygiene scope

- **Goal:** map duplicate conjunction/leg derivation callsites and choose one canonical helper route per flow.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `surface_attachment_contract.zig`, `presentable_contract.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Done when:** queue records contraction map plus `CZH-799` hygiene scope.

### `CZH-792` Tighten seam docs for canonical helper routes

- **Goal:** align docs/comments to explicit canonical helper usage (no parallel derivation stories).
- **Constraint:** docs/comments only; no logic changes.

### `CZH-793` Runtime: canonical conjunction helper path

- **Goal:** route selected runtime conjunction reads through one helper path where currently duplicated.
- **Constraint:** preserve behavior.

### `CZH-794` Surface-state bridge: canonical leg/conjunction read path

- **Goal:** normalize selected surface-state read bridges to one canonical helper route.
- **Constraint:** preserve behavior.

### `CZH-795` Present-result aggregation path wording and callsite alignment

- **Goal:** align selected aggregation callsites/comments with canonical leg/conjunction route.
- **Constraint:** preserve semantics.

### `CZH-796` Widget/draw ownership notes after contraction

- **Goal:** keep widget/draw ownership comments aligned after canonical route contraction.
- **Constraint:** docs/comments and naming only.

### `CZH-797` Add helper-level contraction invariants

- **Goal:** lock helper-level invariants that canonical and legacy-equivalent paths match.

### `CZH-798` Add integration contraction invariants

- **Goal:** lock representative integration invariants across runtime/state/result seams after contraction.

### `CZH-799` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-800` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S25_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-84`.
