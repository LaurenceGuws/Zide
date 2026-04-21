# `CZH-S72` Tickets — Coverage Evidence Invariant Locks

Sprint: `CZH-S72`  
Authority parent: accepted `CZH-B76` coverage evidence consolidation  
Super-gate: `CZH-GATE-131`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Atomic-group commits are forbidden unless explicitly pre-approved by Architect in writing before execution.
- Behavior freeze: invariant-lock tightening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1221` Invariant-lock audit + gap map
- Audit coverage evidence invariants and identify lock gaps.

### `CZH-1222` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` invariant-lock requirements.

### `CZH-1223` Refresh invariant-lock tightening
- Harden refresh-side invariant locks around consolidated evidence.

### `CZH-1224` Reuse invariant-lock tightening
- Harden reuse-side invariant locks around consolidated evidence.

### `CZH-1225` Direct invariant-lock tightening
- Harden direct-side invariant locks around consolidated evidence.

### `CZH-1226` Shared invariant-lock tightening
- Harden shared invariant locks and cross-path consistency checks.

### `CZH-1227` Regression/integration invariant verification
- Verify invariant locks close all identified gaps.

### `CZH-1228` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S72_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-131`.
