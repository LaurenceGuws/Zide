# `CZH-S55` Tickets — Result-surface tightening + test-surface isolation

Sprint: `CZH-S55`  
Authority parent: accepted `CZH-B59` canonical entry/eligibility unification  
Super-gate: `CZH-GATE-114`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: surface tightening/isolation only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1085` Result-surface audit + test-surface map
- Map remaining public helpers used by production vs test-only paths.
- Identify any mixed-surface symbols that should be isolated.

### `CZH-1086` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with explicit production-vs-test helper ownership.

### `CZH-1087` Refresh test-surface isolation cut
- Ensure refresh production path cannot consume test-only fold helpers.
- Keep refresh helper access explicit in tests only.

### `CZH-1088` Reuse test-surface isolation cut
- Ensure reuse production path cannot consume test-only fold helpers.
- Keep reuse helper access explicit in tests only.

### `CZH-1089` Direct test-surface isolation cut
- Ensure direct production path cannot consume test-only fold helpers.
- Keep direct helper access explicit in tests only.

### `CZH-1090` Boundary helper surface tightening
- Remove or narrow any remaining broad helper exposure not needed by production boundary.

### `CZH-1091` Helper/integration invariants lock
- Add helper and integration invariants for non-bypass of canonical entries and explicit test-surface access.

### `CZH-1092` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S55_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-114`.
