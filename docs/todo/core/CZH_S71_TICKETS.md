# `CZH-S71` Tickets — Drift-Guard Coverage Evidence Consolidation

Sprint: `CZH-S71`  
Authority parent: accepted `CZH-B75` verification-surface simplification  
Super-gate: `CZH-GATE-130`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Atomic-group commits are forbidden unless explicitly pre-approved by Architect in writing before execution.
- Behavior freeze: evidence consolidation only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1213` Coverage-evidence audit + consolidation map
- Audit drift-guard coverage evidence for duplication and consolidation candidates.

### `CZH-1214` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` coverage-evidence consolidation criteria.

### `CZH-1215` Refresh coverage-evidence consolidation
- Consolidate refresh evidence while preserving explicit coverage traceability.

### `CZH-1216` Reuse coverage-evidence consolidation
- Consolidate reuse evidence while preserving explicit coverage traceability.

### `CZH-1217` Direct coverage-evidence consolidation
- Consolidate direct evidence while preserving explicit coverage traceability.

### `CZH-1218` Shared coverage-evidence consolidation
- Consolidate shared evidence while preserving cross-path coverage clarity.

### `CZH-1219` Regression/integration coverage integrity verification
- Verify consolidation preserved all drift-guard coverage integrity.

### `CZH-1220` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S71_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-130`.
