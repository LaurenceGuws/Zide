# `CZH-S35` Tickets — Callback-based orchestration extraction

Sprint: `CZH-S35`  
Authority parent: accepted `CZH-B39` plan-decision extraction  
Super-gate: `CZH-GATE-94`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: orchestration ownership extraction only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-891` Callback extraction audit + interface map
- Identify refresh/reuse/direct orchestration functions that still require widget-owned context and define callback interface shapes.

### `CZH-892` Authority tightening (`doc-only`)
- Update authority docs for callback-based terminal orchestrator ownership.

### `CZH-893` Extraction cut A: refresh orchestrator with callbacks
- Move refresh orchestration helper(s) to terminal runtime with callback hooks for integration-only operations.

### `CZH-894` Extraction cut B: reuse orchestrator with callbacks
- Move reuse orchestration helper(s) to terminal runtime with explicit callback interfaces.

### `CZH-895` Extraction cut C: direct-present orchestrator with callbacks
- Move direct-present orchestration helper(s) to terminal runtime with callback hooks.

### `CZH-896` Widget facade contraction
- Reduce widget runtime to integration facade invoking terminal orchestrators.

### `CZH-897` Helper-level invariants
- Add terminal-layer tests that lock callback orchestration behavior equivalence.

### `CZH-898` Integration boundary invariants
- Add widget/terminal integration tests for callback contract compatibility and behavior parity.

### `CZH-899` Hygiene sweep + comment normalization
- Remove probe residue and historical lineage from touched source.

### `CZH-900` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S35_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-94`.
