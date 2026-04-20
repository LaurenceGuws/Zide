# `CZH-S54` Tickets — Canonical entry/eligibility unification

Sprint: `CZH-S54`  
Authority parent: accepted `CZH-B58` outcome-state/internal API contraction  
Super-gate: `CZH-GATE-113`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: unification/contraction only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Run full sprint to super-gate before architect check-in unless hard-blocked.

## Ticket list

### `CZH-1077` Canonical entry/eligibility audit + unification map
- Map remaining duplication between canonical entries and eligibility helpers.
- Identify callsites still carrying redundant entry-routing glue.

### `CZH-1078` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` with unified canonical-entry vocabulary and eligibility ownership.

### `CZH-1079` Refresh entry unification
- Ensure refresh production path has one terminal entry route and no secondary helper hops in widget boundary.

### `CZH-1080` Reuse entry/eligibility unification
- Consolidate reuse eligibility mapping into one canonical terminal entry route.
- Remove any duplicate eligibility-to-outcome glue in widget boundary.

### `CZH-1081` Direct entry/eligibility unification
- Consolidate direct eligibility mapping into one canonical terminal entry route.
- Remove any duplicate direct outcome/entry glue in widget boundary.

### `CZH-1082` Helper surface pruning + boundary glue removal
- Prune non-essential helper aliases left after unification.
- Keep test-critical helpers only where needed for invariant coverage.

### `CZH-1083` Helper/integration invariants lock
- Add helper-level invariants for unified entry/eligibility semantics.
- Add integration invariants that production boundary cannot bypass canonical entries.

### `CZH-1084` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S54_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-113`.
