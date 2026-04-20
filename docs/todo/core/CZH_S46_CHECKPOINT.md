# CZH-S46 Checkpoint — Fold/Result Struct Contraction + Boundary Callsite Collapse

**Sprint:** CZH-S46  
**Batch:** CZH-B51  
**Gate:** CZH-GATE-105  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-1001` through `CZH-1010` were executed in order with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no stale probe/debug residue in touched product paths
- source comments remained present-tense architecture statements only

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-1001 | `a56fe953` | Struct/callsite contraction audit + cut map |
| CZH-1002 | `13a0cf9b` | Authority tightening (doc-only) |
| CZH-1003 | `b4788537` | Refresh result-struct contraction cut |
| CZH-1004 | `7c6b3f21` | Reuse result-struct contraction cut |
| CZH-1005 | `b8ca9087` | Direct result-struct contraction cut |
| CZH-1006 | `d57e820f` | Widget boundary callsite collapse cut |
| CZH-1007 | `fd89240e` | Terminal boundary callsite collapse cut |
| CZH-1008 | `918a5397` | Helper-level invariants for contracted struct/callsite surface |
| CZH-1009 | `c35ce99a` | Integration invariants + hygiene sweep |
| CZH-1010 | (this commit) | Validation packet + gate handoff |

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

- Added struct/callsite contraction audit authority:
  - `docs/todo/core/CZH_1001_STRUCT_CALLSITE_CONTRACTION_AUDIT_MAP.md`
- Tightened architecture authority for contracted fold/result carriers + collapsed callsites:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Contracted refresh/reuse/direct outcome carriers to include canonical transport carrier field.
- Collapsed widget/terminal boundary callsite mapping surface to canonical route usage.
- Added helper and integration invariants locking contracted carrier surface and removed mapping-helper declaration exposure.

## Board / Gate Notes

- Sprint moved to `review_gate` at `CZH-GATE-105` in `docs/todo/core/JIRA_BOARD.md`.
- Architect remains owner for movement from `review_gate` to `done`.

## Files touched in this sprint window

- `docs/todo/core/CZH_1001_STRUCT_CALLSITE_CONTRACTION_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/implementation.md`
- `docs/todo/core/JIRA_BOARD.md`
