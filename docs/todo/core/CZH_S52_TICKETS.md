# `CZH-S52` Tickets — Canonical fold-entry consolidation (larger cut)

Sprint: `CZH-S52`  
Authority parent: accepted `CZH-B56` route/assertion minimization  
Super-gate: `CZH-GATE-111`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: consolidation only; no semantic/runtime behavior change.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- This sprint is a longer engineering loop: prefer 8 coherent commits before super-gate (no mid-loop architect review).

## Ticket list

### `CZH-1061` Canonical fold-entry audit + callsite map
- Enumerate refresh/reuse/direct fold-entry callsites and classify any remaining alias/helper indirection.
- Produce one map doc with exact source callsites and target canonical routes.

### `CZH-1062` Authority tightening (`doc-only`)
- Update `TERMINAL_SURFACE_CONTRACT.md` to document one canonical fold entry per flow and widget-as-facade boundary.

### `CZH-1063` Refresh flow consolidation (single terminal fold entry)
- Collapse refresh fold-entry callsites onto one canonical terminal runtime route.
- Remove refresh-side alias glue in widget/runtime boundary.

### `CZH-1064` Reuse flow consolidation (single terminal fold entry)
- Collapse reuse fold-entry callsites onto one canonical terminal runtime route.
- Remove reuse-side alias glue in widget/runtime boundary.

### `CZH-1065` Direct flow consolidation (single terminal fold entry)
- Collapse direct fold-entry callsites onto one canonical terminal runtime route.
- Remove direct-side alias glue in widget/runtime boundary.

### `CZH-1066` Boundary struct/threading contraction
- Remove any redundant fold-route threading fields/params that no longer carry distinct ownership value.
- Keep one canonical data handoff per flow (refresh/reuse/direct).

### `CZH-1067` Helper + integration invariants lock
- Add helper-level invariants for the canonical entry routes.
- Add integration invariants that widget/runtime boundary cannot bypass canonical terminal fold entries.

### `CZH-1068` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add checkpoint doc `CZH_S52_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-111`.
