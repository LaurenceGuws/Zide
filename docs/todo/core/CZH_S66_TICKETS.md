# `CZH-S66` Tickets — Enforcement Evidence Surface Normalization

Sprint: `CZH-S66`  
Authority parent: accepted `CZH-B70` enforcement signal compression  
Super-gate: `CZH-GATE-125`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: evidence normalization only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1173` Evidence audit + normalization map
- Audit current enforcement evidence artifacts for overlaps/duplication and map normalization cuts.

### `CZH-1174` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` evidence-normalization policy and traceability criteria.

### `CZH-1175` Refresh evidence normalization
- Normalize refresh evidence structure while preserving explicit traceability to locks/tests.

### `CZH-1176` Reuse evidence normalization
- Normalize reuse evidence structure while preserving explicit traceability to locks/tests.

### `CZH-1177` Direct evidence normalization
- Normalize direct evidence structure while preserving explicit traceability to locks/tests.

### `CZH-1178` Shared evidence normalization
- Normalize shared evidence structure while preserving cross-path traceability.

### `CZH-1179` Regression/integration traceability verification
- Verify normalized evidence still maps unambiguously to compile/test enforcement.

### `CZH-1180` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S66_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-125`.
