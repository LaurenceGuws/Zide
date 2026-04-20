# `CZH-S56` Tickets — Canonical entry contract lockdown + exposure prune

Sprint: `CZH-S56`  
Authority parent: accepted `CZH-B60` result-surface tightening + test-surface isolation  
Super-gate: `CZH-GATE-115`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: contract lockdown/pruning only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1093` Canonical entry contract audit + exposure map
- Map every production entry route and remaining helper exposure against canonical contract.

### `CZH-1094` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` for strict canonical-entry contract and helper exposure rules.

### `CZH-1095` Refresh contract lockdown
- Remove/lock any residual non-canonical refresh route exposure.

### `CZH-1096` Reuse contract lockdown
- Remove/lock any residual non-canonical reuse route exposure.

### `CZH-1097` Direct contract lockdown
- Remove/lock any residual non-canonical direct route exposure.

### `CZH-1098` Helper exposure prune
- Prune non-essential helper exposure while preserving explicit test-only access where required.

### `CZH-1099` Helper/integration invariants lock
- Add helper + integration invariants for no-bypass and route parity under canonical contract.

### `CZH-1100` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S56_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-115`.
