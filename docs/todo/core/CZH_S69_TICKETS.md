# `CZH-S69` Tickets — Enforcement Matrix Drift-Guard Tightening

Sprint: `CZH-S69`  
Authority parent: accepted `CZH-B73` matrix determinism hardening  
Super-gate: `CZH-GATE-128`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Atomic-group commits are forbidden unless explicitly pre-approved by Architect in writing before execution.
- Behavior freeze: drift-guard tightening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1197` Drift-guard audit + gap map
- Audit matrix drift vectors remaining after determinism hardening.

### `CZH-1198` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` drift-guard criteria and update policy.

### `CZH-1199` Refresh drift-guard tightening
- Add/align refresh-side guards against claim/lock drift.

### `CZH-1200` Reuse drift-guard tightening
- Add/align reuse-side guards against claim/lock drift.

### `CZH-1201` Direct drift-guard tightening
- Add/align direct-side guards against claim/lock drift.

### `CZH-1202` Shared drift-guard tightening
- Add/align shared cross-path guards against matrix drift.

### `CZH-1203` Regression/integration drift verification
- Verify drift-guard coverage closes all identified vectors.

### `CZH-1204` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S69_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-128`.
