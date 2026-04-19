# `CZH-S19` Tickets — long-loop surface observability vocabulary lock

Sprint: `CZH-S19`  
Authority parent: accepted surface state vocabulary lock (`CZH-B23`)  
Super-gate: `CZH-GATE-78`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-740` unless a real hard blocker appears.

## Ticket list

### `CZH-731` Observability vocabulary audit + hygiene scope

- **Goal:** map selected logging/telemetry vocabulary drift vs locked state model.
- **Targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget.zig`, `terminal_widget_draw.zig`, `terminal_widget_surface_state.zig`, `surface_contract.zig`, `surface_attachment_contract.zig`.
- **Done when:** implementation queue records classified signals and `CZH-739` hygiene scope.

### `CZH-732` Tighten observability doc strings

- **Goal:** align observability-oriented docs/comments with pipeline-leg, host-target-leg, full-attachment, and generation ownership.
- **Constraint:** docs-only tightening; no logic changes.

### `CZH-733` Converge selected generation-owned observability keys

- **Goal:** align selected generation-focused signal names/keys in touched runtime paths.
- **Constraint:** no behavior changes.

### `CZH-734` Converge selected attachment-owned observability keys

- **Goal:** align selected attachment-focused signal names/keys in touched runtime paths.
- **Constraint:** no behavior changes.

### `CZH-735` Converge selected pipeline-leg observability keys

- **Goal:** align selected pipeline-leg signal names/keys in touched runtime/state paths.
- **Constraint:** preserve existing semantics.

### `CZH-736` Converge selected draw/widget observability vocabulary

- **Goal:** align selected draw/widget logs to the same state-vocabulary split.
- **Constraint:** no signal removal unless stale probe residue is proven.

### `CZH-737` Add helper-level observability invariants tests

- **Goal:** lock representative invariants connecting observability vocabulary to unchanged helper semantics.

### `CZH-738` Add runtime/widget integration observability invariants

- **Goal:** lock representative integration invariants for observability vocabulary across selected touched paths.

### `CZH-739` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files and sync authority wording to landed code only.
- **Done when:** queue note records removed/kept signals + rationale.

### `CZH-740` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S19_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-78`.
