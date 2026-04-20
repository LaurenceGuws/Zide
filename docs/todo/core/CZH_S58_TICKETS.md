# `CZH-S58` Tickets — Entry contract compression + assertion surface trim

Sprint: `CZH-S58`  
Authority parent: accepted `CZH-B62` contract-only production surface audit + exposure lock  
Super-gate: `CZH-GATE-117`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: compression/trim only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1109` Entry/Assertion surface audit + compression map
- Map compressible assertion/exposure layers around canonical entry contract.

### `CZH-1110` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with compressed contract and assertion-surface policy.

### `CZH-1111` Refresh entry surface compression
- Trim non-essential refresh assertion/exposure layers while preserving no-bypass semantics.

### `CZH-1112` Reuse entry surface compression
- Trim non-essential reuse assertion/exposure layers while preserving no-bypass semantics.

### `CZH-1113` Direct entry surface compression
- Trim non-essential direct assertion/exposure layers while preserving no-bypass semantics.

### `CZH-1114` Shared assertion-surface trim
- Reduce duplicated assertion/exposure layers across flows where contract-equivalent.

### `CZH-1115` Helper/integration invariants lock
- Lock parity + no-bypass invariants after compression/trim.

### `CZH-1116` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S58_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-117`.
