# `CZH-S67` Tickets — Enforcement Claim-to-Lock Trace Matrix Hardening

Sprint: `CZH-S67`  
Authority parent: accepted `CZH-B71` evidence normalization  
Super-gate: `CZH-GATE-126`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit (atomic-group only with explicit architect pre-approval).
- Behavior freeze: trace hardening only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1181` Claim-to-lock trace audit + matrix map
- Build matrix of enforcement claims to concrete compile/test locks and identify ambiguities.

### `CZH-1182` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` trace-matrix requirements and acceptance criteria.

### `CZH-1183` Refresh trace hardening
- Harden refresh claim-to-lock mapping for explicit one-to-one traceability.

### `CZH-1184` Reuse trace hardening
- Harden reuse claim-to-lock mapping for explicit one-to-one traceability.

### `CZH-1185` Direct trace hardening
- Harden direct claim-to-lock mapping for explicit one-to-one traceability.

### `CZH-1186` Shared trace hardening
- Harden shared claim-to-lock mapping and cross-path matrix clarity.

### `CZH-1187` Regression/integration matrix verification
- Verify no ambiguous/unmapped claims remain after hardening.

### `CZH-1188` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S67_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-126`.
