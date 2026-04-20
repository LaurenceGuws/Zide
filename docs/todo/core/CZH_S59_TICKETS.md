# `CZH-S59` Tickets — Canonical entry contract final surface seal

Sprint: `CZH-S59`  
Authority parent: accepted `CZH-B63` entry contract compression + assertion surface trim  
Super-gate: `CZH-GATE-118`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: contract seal only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1117` Final surface-seal audit + edge map
- Map residual helper exposure edges around canonical production entry contract.

### `CZH-1118` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with final-seal contract wording.

### `CZH-1119` Refresh surface edge seal
- Remove/constrain residual refresh helper exposure edges.

### `CZH-1120` Reuse surface edge seal
- Remove/constrain residual reuse helper exposure edges.

### `CZH-1121` Direct surface edge seal
- Remove/constrain residual direct helper exposure edges.

### `CZH-1122` Shared helper exposure edge trim
- Trim shared exposure edges across flows while preserving parity guarantees.

### `CZH-1123` Helper/integration invariants final lock
- Lock final no-bypass/parity invariants for sealed contract.

### `CZH-1124` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S59_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-118`.
