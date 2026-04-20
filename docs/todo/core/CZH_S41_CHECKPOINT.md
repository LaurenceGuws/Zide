# CZH-S41 Checkpoint — Boundary Alias Pruning + Surface Contract Narrowing

**Sprint:** CZH-S41  
**Batch:** CZH-B46  
**Gate:** CZH-GATE-100  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-951` through `CZH-960` were executed in strict order with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no ticket/sprint lineage added to source comments
- widget remained integration facade while terminal retained decision/fold semantics

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-951 | `10b4bf7f` | Alias/vocabulary audit + pruning map |
| CZH-952 | `7100815b` | Authority tightening (doc-only) |
| CZH-953 | `49055d7d` | Refresh alias pruning |
| CZH-954 | `dbe07a5e` | Reuse alias pruning |
| CZH-955 | `8874e740` | Direct/fold alias pruning |
| CZH-956 | `fbb2d606` | Widget/runtime boundary cleanup |
| CZH-957 | `9cc7d2a9` | Helper-level invariants |
| CZH-958 | `efccb67a` | Integration invariants |
| CZH-959 | `baf51942` | Hygiene sweep |
| CZH-960 | (this commit) | Validation packet + gate handoff |

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

### 1) Alias/vocabulary audit and pruning authority

- Added explicit alias/vocabulary audit map:
  - `docs/todo/core/CZH_951_ALIAS_VOCAB_AUDIT_MAP.md`
- Established canonical transport vocabulary for refresh/reuse/direct boundary terms and replacement map.

### 2) Surface contract narrowing (doc authority)

- Updated terminal surface contract language to canonical transport terms:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Narrowed wording around:
  - refresh boundary helper semantics
  - reuse boundary helper semantics
  - host-facing folded result transport ownership
  - no re-derivation and single-path transport rules

### 3) Refresh alias pruning

- Renamed widget refresh helper to canonical refresh boundary term:
  - `runRefreshedPresentablePresentation(...)` → `runRefreshBoundaryPresentationResult(...)`
- Updated callsites and refresh-boundary terminology in runtime docs/comments.
- Kept refresh behavior and fold semantics unchanged.

### 4) Reuse alias pruning

- Added explicit canonical alias export at widget boundary:
  - `presentResultFromReuseOutcomeState` -> canonical alias of `foldReuseAttemptResultToPresent`
- Updated integration terminology/tests to canonical reuse boundary helper vocabulary.
- Preserved single-path reuse fold route and behavior parity.

### 5) Direct/fold alias pruning

- Pruned direct/fold terminology drift in terminal runtime docs/comments:
  - normalized to direct boundary / direct folded-result vocabulary
- Updated integration test wording/variable naming to canonical direct folded-result language.
- No direct path behavior changes.

### 6) Widget/runtime boundary cleanup

- Removed stale widget-local alias residue in refresh boundary test carriers:
  - local test carrier now uses narrowed folded-result shape (`present_result`) consistently.

### 7) Invariants and compatibility locks

- Helper invariants (`src/terminal/test_presentation_runtime.zig`) expanded to lock:
  - refresh boundary helper route parity with canonical refresh fold route
  - reuse fold alias parity with canonical reuse boundary helper route
  - direct folded-result vocabulary route parity
- Integration invariants (`src/ui/widgets/test_presentation_runtime_integration.zig`) expanded to lock:
  - refresh boundary helper naming parity + host-facing folded carrier equivalence
  - reuse canonical alias export parity against widget and terminal boundary helpers
  - direct folded-result route parity with canonical direct timing carrier

### 8) Hygiene

- Completed hygiene sweep (`CZH-959`) with no behavior/ABI changes and no stale ticket/sprint lineage in source comments.

## Board / Gate Notes

- Per board rules, movement into `review_gate` / `done` remains Architect-owned.
- This document is the engineer gate packet for `CZH-GATE-100`.

## Files touched in this sprint window

- `docs/todo/core/CZH_951_ALIAS_VOCAB_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
