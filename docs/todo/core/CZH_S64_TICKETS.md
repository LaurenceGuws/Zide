# `CZH-S64` Tickets — Enforcement Surface Compaction with Lock Preservation

Sprint: `CZH-S64`  
Authority parent: accepted `CZH-B68` runtime-to-test binding tightening  
Super-gate: `CZH-GATE-123`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: compaction + lock preservation only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1157` Compaction audit + preservation map
- Audit enforcement docs/helpers/tests for compaction candidates that do not weaken lock guarantees.

### `CZH-1158` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` compaction policy with lock-preservation criteria.

### `CZH-1159` Refresh compaction
- Compact refresh enforcement representation while preserving existing bindings/guards.

### `CZH-1160` Reuse compaction
- Compact reuse enforcement representation while preserving existing bindings/guards.

### `CZH-1161` Direct compaction
- Compact direct enforcement representation while preserving existing bindings/guards.

### `CZH-1162` Shared compaction
- Compact shared enforcement representation while preserving cross-path lock clarity.

### `CZH-1163` Regression/integration lock preservation verification
- Verify compaction left all no-bypass and drift locks intact.

### `CZH-1164` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S64_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-123`.
