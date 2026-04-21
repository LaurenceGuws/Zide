# `CZH-S70` Tickets — Drift-Guard Verification Surface Simplification

Sprint: `CZH-S70`  
Authority parent: accepted `CZH-B74` drift-guard tightening  
Super-gate: `CZH-GATE-129`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Atomic-group commits are forbidden unless explicitly pre-approved by Architect in writing before execution.
- Behavior freeze: verification-surface simplification only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1205` Verification-surface audit + simplification map
- Audit drift-guard verification surface for duplication and simplification candidates.

### `CZH-1206` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` verification-surface criteria.

### `CZH-1207` Refresh verification-surface simplification
- Simplify refresh verification surface without reducing guard coverage.

### `CZH-1208` Reuse verification-surface simplification
- Simplify reuse verification surface without reducing guard coverage.

### `CZH-1209` Direct verification-surface simplification
- Simplify direct verification surface without reducing guard coverage.

### `CZH-1210` Shared verification-surface simplification
- Simplify shared verification surface without reducing cross-path guard clarity.

### `CZH-1211` Regression/integration coverage preservation verification
- Verify simplification preserved all drift-guard coverage.

### `CZH-1212` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S70_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-129`.
