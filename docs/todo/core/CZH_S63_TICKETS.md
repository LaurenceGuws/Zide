# `CZH-S63` Tickets — Governance Runtime-to-Test Binding Tightening

Sprint: `CZH-S63`  
Authority parent: accepted `CZH-B67` governance simplification + sustained enforcement  
Super-gate: `CZH-GATE-122`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: enforcement binding tightening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1149` Binding audit + gap map
- Audit runtime enforcement claims vs test coverage and map missing explicit bindings.

### `CZH-1150` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` with explicit runtime-to-test binding policy.

### `CZH-1151` Refresh binding tightening
- Ensure refresh enforcement claims map to explicit test or compile locks.

### `CZH-1152` Reuse binding tightening
- Ensure reuse enforcement claims map to explicit test or compile locks.

### `CZH-1153` Direct binding tightening
- Ensure direct enforcement claims map to explicit test or compile locks.

### `CZH-1154` Shared binding tightening
- Ensure shared enforcement claims map to explicit test or compile locks.

### `CZH-1155` Regression/integration binding verification
- Verify no unbound enforcement claims remain and drift vectors stay guarded.

### `CZH-1156` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S63_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-122`.
