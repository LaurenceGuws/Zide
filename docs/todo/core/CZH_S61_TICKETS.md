# `CZH-S61` Tickets — Governance Enforcement Tightening

Sprint: `CZH-S61`  
Authority parent: accepted `CZH-B65` post-seal governance baseline  
Super-gate: `CZH-GATE-120`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: governance enforcement tightening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1133` Governance enforcement audit + gap map
- Audit current enforcement points vs governance baseline.
- Produce a concrete gap map for missing compile/test/runtime guards.

### `CZH-1134` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with explicit enforcement ownership and escalation criteria.

### `CZH-1135` Refresh enforcement tightening
- Strengthen refresh-path governance guards where drift could re-open non-canonical surfaces.

### `CZH-1136` Reuse enforcement tightening
- Strengthen reuse-path governance guards with explicit no-bypass enforcement.

### `CZH-1137` Direct enforcement tightening
- Strengthen direct-path governance guards and canonical-entry protection.

### `CZH-1138` Shared enforcement tightening
- Tighten shared transport/result/helper boundaries so drift fails fast.

### `CZH-1139` Regression/integration lock expansion
- Expand helper + integration locks to cover newly hardened governance checks.

### `CZH-1140` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S61_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-120`.
