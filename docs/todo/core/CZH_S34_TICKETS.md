# `CZH-S34` Tickets — Runtime orchestration ownership completion

Sprint: `CZH-S34`  
Authority parent: accepted `CZH-B38` extraction and hygiene  
Super-gate: `CZH-GATE-93`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze: ownership movement and orchestration extraction only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-881` Orchestration boundary audit + cut map
- Map pure orchestration helpers still in widget runtime and lock move order.

### `CZH-882` Authority tightening (`doc-only`)
- Update authority docs so orchestrator ownership boundary is explicit.

### `CZH-883` Extraction cut A: refresh-cycle orchestration helpers
- Move pure refresh orchestration helpers into terminal runtime seam.

### `CZH-884` Extraction cut B: reuse/direct orchestration helpers
- Move pure reuse/direct orchestration helpers into terminal runtime seam.

### `CZH-885` Facade contraction in widget runtime
- Reduce widget runtime to integration-oriented calls into terminal runtime.

### `CZH-886` Ownership hardening tests (helper level)
- Add helper-level tests locking no behavior drift after extraction.

### `CZH-887` Integration boundary tests
- Add integration tests locking widget-facade/terminal-runtime boundary.

### `CZH-888` Android pressure guard + shared-path check
- Run Android compile guard for seam safety and record outcomes.

### `CZH-889` Probe/doc hygiene sweep
- Remove stale debug/probe residue and historical lineage from touched source.

### `CZH-890` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S34_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-93`.
