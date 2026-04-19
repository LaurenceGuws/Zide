# `CZH-S18` Tickets — long-loop surface state vocabulary lock

Sprint: `CZH-S18`  
Authority parent: accepted naming/state convergence pack (`CZH-B22`)  
Super-gate: `CZH-GATE-77`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-730` unless a real hard blocker appears.

## Ticket list

### `CZH-721` Vocabulary/state drift audit + hygiene scope

- **Goal:** map selected drift where pipeline leg, full attachment, and generation terms diverge.
- **Targets:** `terminal_widget_presentation_state.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_runtime.zig`, `terminal_widget_draw.zig`, `surface_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** implementation queue records classified touchpoints and `CZH-729` hygiene scope.

### `CZH-722` Tighten doc strings for state-vocabulary lock

- **Goal:** tighten module/struct/field docs so the three state categories are explicit and non-overlapping.
- **Constraint:** docs-only ownership tightening; no logic change.

### `CZH-723` Converge selected generation-owned naming in runtime/state

- **Goal:** align selected generation-owned symbols/callers to `surface_contract` vocabulary.
- **Constraint:** no behavior changes.

### `CZH-724` Converge selected attachment-owned naming in runtime/state

- **Goal:** align selected attachment-owned symbols/callers to `surface_attachment_contract` vocabulary.
- **Constraint:** no behavior changes.

### `CZH-725` Converge selected pipeline-leg naming in delta/state

- **Goal:** align selected pipeline-leg symbols/callers to one stable term set.
- **Constraint:** preserve all existing semantics.

### `CZH-726` Converge selected logging/telemetry key vocabulary

- **Goal:** align selected touched log/telemetry keys to the same state-vocabulary split.
- **Constraint:** no signal removal unless stale probe residue is proven.

### `CZH-727` Add helper-level invariants tests for vocabulary split

- **Goal:** lock representative invariants mapping vocabulary categories to unchanged predicates/helpers.

### `CZH-728` Add integration invariants tests in widget/runtime paths

- **Goal:** lock representative integration invariants for pipeline leg vs full attachment vs generation terms.

### `CZH-729` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-730` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S18_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-77`.
