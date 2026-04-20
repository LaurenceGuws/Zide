# CZH-S44 Checkpoint — Boundary Fold-Route Unification + Transport-Field Contraction

**Sprint:** CZH-S44  
**Batch:** CZH-B49  
**Gate:** CZH-GATE-103  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-981` through `CZH-990` were executed with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no stale probe/debug residue in touched product paths
- source comments remained present-tense architecture statements only

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-981 | `d419cd38` | Fold-route/field contraction audit + cut map |
| CZH-982 | `176a009b` | Authority tightening (doc-only) |
| CZH-983 | `3b6cb6aa` | Refresh fold-route unification cut |
| CZH-984 | `2938ac6c` | Reuse fold-route unification cut |
| CZH-985 | `d816426e` | Direct-present fold-route unification cut |
| CZH-986 | `cf34a268` | Refresh transport-field contraction cut |
| CZH-987 | `0a8c1033` | Reuse/direct transport-field contraction cut |
| CZH-988 | `b6e52330` | Helper-level invariants for unified fold routes |
| CZH-989 | `eb180565` | Integration invariants + hygiene sweep |
| CZH-990 | (this commit) | Validation packet + gate handoff |

## Validation

### Required ladder

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `timeout 3s zig build run -- --mode terminal` — **PASS** (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- `python3 ops/android_terminal_host.py deploy` — **PASS**
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — **PASS** (no AndroidRuntime errors)

## Key Changes (Behavior-Neutral)

- Added fold-route/field-contraction audit authority:
  - `docs/todo/core/CZH_981_FOLD_ROUTE_FIELD_CONTRACTION_AUDIT_MAP.md`
- Tightened architecture authority for unified fold-route naming and contracted field carriers:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Unified refresh/reuse/direct fold route helper names to one canonical pattern.
- Contracted refresh followup transport into a nested `followup` field on refresh outcome carrier.
- Contracted reuse/direct fold transport threading through shared `FoldTransportFields` carrier.
- Added helper-level and integration invariants locking unified fold routes and contracted field carriers.

## Board / Gate Notes

- Sprint moved to `review_gate` at `CZH-GATE-103` in `docs/todo/core/JIRA_BOARD.md`.
- Architect remains owner for movement from `review_gate` to `done`.

## Files touched in this sprint window

- `docs/todo/core/CZH_981_FOLD_ROUTE_FIELD_CONTRACTION_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/implementation.md`
- `docs/todo/core/JIRA_BOARD.md`
