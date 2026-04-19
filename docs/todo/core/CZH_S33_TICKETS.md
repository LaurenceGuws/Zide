# `CZH-S33` Tickets — Terminal presentation runtime ownership extraction

Sprint: `CZH-S33`  
Authority parent: accepted `CZH-B37` caller-ownership mobility  
Super-gate: `CZH-GATE-92`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze by default; this sprint is ownership extraction and contract hardening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no fallback compatibility branches.
- Source comments in touched product files stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Windows/macOS are non-blocking unless their platform-owned code is touched.

## Ticket list

### `CZH-871` Runtime ownership audit + move map
- Map exact symbols in `terminal_widget_presentation_runtime.zig` to move into `src/terminal/presentation_runtime.zig`.
- Lock “keep in widget” exclusions and hygiene scope.

### `CZH-872` Authority tightening (`doc-only`)
- Update authority docs so runtime orchestration ownership is explicit before code movement.

### `CZH-873` Extraction cut A: pure outcome helpers
- Move pure present/outcome helpers into terminal-owned runtime module.

### `CZH-874` Extraction cut B: attachment/pipeline fold helpers
- Move fold/composition helpers without semantic changes.

### `CZH-875` Extraction cut C: runtime orchestrator entrypoint
- Introduce terminal-owned runtime entrypoint called by widget facade.

### `CZH-876` Widget facade contraction
- Reduce widget runtime file to thin adapter calls into terminal runtime module.

### `CZH-877` Helper-level invariants
- Add tests that lock canonical helper routing after extraction.

### `CZH-878` Integration invariants
- Add integration tests proving no behavior drift across refresh/reuse paths.

### `CZH-879` Probe/doc hygiene + naming sweep
- Remove stale probe/debug residue and ticket-history wording in touched source files.

### `CZH-880` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S33_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-92`.
