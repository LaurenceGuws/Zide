# `CZH-S62` Tickets — Governance Simplification and Sustained Enforcement

Sprint: `CZH-S62`  
Authority parent: accepted `CZH-B66` governance enforcement tightening  
Super-gate: `CZH-GATE-121`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: simplification + enforcement preservation only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1141` Enforcement surface audit + simplification map
- Map governance docs/checks that are redundant after S60/S61 and identify safe simplification cuts.

### `CZH-1142` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` to a concise sustained-enforcement policy.

### `CZH-1143` Refresh enforcement simplification
- Simplify refresh-path governance wording/check mapping while preserving guard strength.

### `CZH-1144` Reuse enforcement simplification
- Simplify reuse-path governance wording/check mapping while preserving guard strength.

### `CZH-1145` Direct enforcement simplification
- Simplify direct-path governance wording/check mapping while preserving guard strength.

### `CZH-1146` Shared enforcement simplification
- Simplify shared transport/result/helper governance mapping and remove duplication.

### `CZH-1147` Regression/integration sustained lock verification
- Prove simplified mapping still protects no-bypass and drift vectors.

### `CZH-1148` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S62_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-121`.
