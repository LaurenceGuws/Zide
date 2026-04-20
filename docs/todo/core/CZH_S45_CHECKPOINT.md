# CZH-S45 Checkpoint — Terminal/Widget Fold API Narrowing + Field-Shape Lock

**Sprint:** CZH-S45  
**Batch:** CZH-B50  
**Gate:** CZH-GATE-104  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-991` through `CZH-1000` were executed in order with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no stale probe/debug residue in touched product paths
- source comments remained present-tense architecture statements only

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-991 | `9a548329` | Fold API/field-shape audit + cut map |
| CZH-992 | `63085e2e` | Authority tightening (doc-only) |
| CZH-993 | `0e0d4a36` | Refresh fold API narrowing |
| CZH-994 | `1075b5eb` | Reuse fold API narrowing |
| CZH-995 | `79c59c22` | Direct fold API narrowing |
| CZH-996 | `b6187044` | Refresh/reuse field-shape lock cut |
| CZH-997 | `da5e6022` | Direct field-shape lock cut |
| CZH-998 | `f84c000d` | Helper-level invariants for narrowed API + locked field shapes |
| CZH-999 | `9139742a` | Integration invariants + hygiene sweep |
| CZH-1000 | (this commit) | Validation packet + gate handoff |

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

- Added audit authority:
  - `docs/todo/core/CZH_991_FOLD_API_FIELD_SHAPE_AUDIT_MAP.md`
- Tightened architecture authority for narrowed fold API + field-shape lock:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Narrowed fold API surface by removing/publicly hiding generic fold composition helpers from terminal/widget boundary usage.
- Locked refresh/reuse/direct field-shape mapping through canonical fold field-mapping helpers and direct carrier shape assertions.
- Added helper-level and integration-level invariants to lock narrowed API exposure and canonical field shapes.

## Board / Gate Notes

- Sprint moved to `review_gate` at `CZH-GATE-104` in `docs/todo/core/JIRA_BOARD.md`.
- Architect remains owner for movement from `review_gate` to `done`.

## Files touched in this sprint window

- `docs/todo/core/CZH_991_FOLD_API_FIELD_SHAPE_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/implementation.md`
- `docs/todo/core/JIRA_BOARD.md`
