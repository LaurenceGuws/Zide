# `CZH-S53` Tickets — Outcome-state/internal API contraction

Sprint: `CZH-S53`  
Authority parent: accepted `CZH-B57` canonical fold-entry consolidation  
Super-gate: `CZH-GATE-112`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: consolidation/contraction only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Longer engineering loop: execute full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1069` Outcome-state usage audit + contraction map
- Map remaining production handling of outcome-state types across widget/runtime boundary.
- Identify removable alias/re-export/helper surfaces with exact callsites.

### `CZH-1070` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` to reflect result-only widget/runtime boundary and terminal-owned outcome internals.

### `CZH-1071` Refresh boundary contraction
- Remove refresh production dependence on outcome-state type exposure outside terminal runtime.
- Keep only canonical `refreshPresentEntry(...)` route in production boundary.

### `CZH-1072` Reuse boundary contraction
- Remove reuse production dependence on outcome-state type exposure outside terminal runtime.
- Keep only canonical `reusePresentEntry(...)` route in production boundary.

### `CZH-1073` Direct boundary contraction
- Remove direct production dependence on outcome-state type exposure outside terminal runtime.
- Keep only canonical `directPresentEntry(...)` route in production boundary.

### `CZH-1074` Internal helper surface pruning
- Prune non-essential public helper aliases exposed for production paths.
- Keep test-critical helpers only where needed for granular invariants.

### `CZH-1075` Helper/integration invariants lock
- Add helper-level invariants proving canonical entries preserve parity with remaining helper routes.
- Add integration tests proving widget production paths cannot bypass canonical entries.

### `CZH-1076` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S53_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-112`.
