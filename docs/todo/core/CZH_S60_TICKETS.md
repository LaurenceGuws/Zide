# `CZH-S60` Tickets — Post-seal contract governance baseline

Sprint: `CZH-S60`  
Authority parent: accepted `CZH-B64` canonical entry contract final surface seal  
Super-gate: `CZH-GATE-119`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: governance/lock baseline only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1125` Post-seal governance audit + change-vector map
- Map potential extension/change vectors against sealed contract and identify required lock points.

### `CZH-1126` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with post-seal governance policy and change-control criteria.

### `CZH-1127` Refresh governance lock baseline
- Add refresh-specific governance checks/locks for sealed contract preservation.

### `CZH-1128` Reuse governance lock baseline
- Add reuse-specific governance checks/locks for sealed contract preservation.

### `CZH-1129` Direct governance lock baseline
- Add direct-specific governance checks/locks for sealed contract preservation.

### `CZH-1130` Shared governance lock baseline
- Add shared governance locks spanning entry surfaces and helper exposure edges.

### `CZH-1131` Regression/integration governance locks
- Add regression/integration locks covering post-seal drift scenarios and no-bypass guarantees.

### `CZH-1132` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S60_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-119`.
