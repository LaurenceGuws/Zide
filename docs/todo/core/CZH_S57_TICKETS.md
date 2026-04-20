# `CZH-S57` Tickets — Contract-only production surface audit + exposure lock

Sprint: `CZH-S57`  
Authority parent: accepted `CZH-B61` canonical entry contract lockdown + exposure prune  
Super-gate: `CZH-GATE-116`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: contract-surface tightening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1101` Production-callable surface audit + map
- Map all production-callable helpers and entry points against canonical contract.

### `CZH-1102` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with production-callable surface lock language.

### `CZH-1103` Refresh surface lock
- Ensure refresh production path has no non-canonical callable helper exposure.

### `CZH-1104` Reuse surface lock
- Ensure reuse production path has no non-canonical callable helper exposure.

### `CZH-1105` Direct surface lock
- Ensure direct production path has no non-canonical callable helper exposure.

### `CZH-1106` Exposure prune/justification cut
- Remove non-essential public exposure or add explicit test-only justification docs for retained exposure.

### `CZH-1107` Helper/integration invariants lock
- Add invariants proving no-bypass production callable surface and route parity.

### `CZH-1108` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S57_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-116`.
