# CZH-S40 Checkpoint — Refresh/Reuse Transport Boundary Consolidation

**Sprint:** CZH-S40  
**Batch:** CZH-B45  
**Gate:** CZH-GATE-99  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-941` through `CZH-950` were executed in strict order with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no ticket/sprint lineage added to source comments
- widget remained integration facade while terminal retained decision/fold semantics

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-941 | `509b61aa` | Transport boundary audit + consolidation map |
| CZH-942 | `97066e49` | Authority tightening (doc-only) |
| CZH-943 | `273a69ac` | Refresh transport boundary consolidation |
| CZH-944 | `f6ab3ce0` | Reuse transport boundary consolidation |
| CZH-945 | `54b7b1f3` | Boundary helper simplification |
| CZH-946 | `fe8589ac` | Widget/runtime boundary cleanup |
| CZH-947 | `4afedb39` | Helper-level invariants |
| CZH-948 | `cb20133a` | Integration invariants |
| CZH-949 | `ee3efa3f` | Hygiene sweep |
| CZH-950 | (this commit) | Validation packet + gate handoff |

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

### 1) Boundary audit + authority lock

- Added explicit refresh/reuse boundary audit map:
  - `docs/todo/core/CZH_941_TRANSPORT_BOUNDARY_AUDIT_MAP.md`
- Tightened architecture authority to reflect consolidated refresh/reuse transport ownership:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`

### 2) Refresh boundary consolidation

- Consolidated refresh boundary carrier to terminal-owned host-facing fold result:
  - `RefreshedPresentablePresentationResult` now carries `present_result: TerminalPresentResult`
- Added canonical terminal helper:
  - `refreshedPresentationResultFromCycle(refresh, shared_surface_attachment_ready, timing)`
- Updated refresh flow contract:
  - `executeRefreshPresentFlow(...)` now returns the pre-folded host-facing result from the refresh boundary carrier directly

### 3) Reuse boundary consolidation

- Added canonical reuse boundary helper:
  - `foldReuseAttemptResultToPresent(...)`
- Preserved single-path reuse fold route:
  - `presentResultFromReuseOutcomeState(...)` delegates to the boundary helper
- Updated widget reuse boundary to call terminal canonical helper:
  - `runFastPresentIfAvailable(...)` now routes reuse-attempt output through terminal-owned boundary fold helper

### 4) Boundary helper simplification + cleanup

- Simplified widget helper aliasing to use explicit canonical reuse boundary helper naming.
- Removed residual boundary glue duplication where helper routes were already consolidated.

### 5) Contract locking via tests

- Helper-level tests (`src/terminal/test_presentation_runtime.zig`) now lock:
  - refresh boundary helper host-facing transport fields (including unavailable/followup transport)
  - reuse boundary helper parity for reused + non-reused attempts
  - wrapper parity between canonical reuse fold entrypoints
- Integration tests (`src/ui/widgets/test_presentation_runtime_integration.zig`) now lock:
  - refresh boundary host-facing transport parity
  - reuse boundary alias/helper equivalence at widget/terminal seam
  - no re-derivation or boundary drift for refresh/reuse fold transport

### 6) Hygiene

- Hygiene sweep committed for touched seams (`CZH-949`) with no behavior/ABI changes.

## Board / Gate Notes

- Per board rules, movement into `review_gate` / `done` remains Architect-owned.
- This document is the engineer gate packet for `CZH-GATE-99`.

## Files touched in this sprint window

- `docs/todo/core/CZH_941_TRANSPORT_BOUNDARY_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
