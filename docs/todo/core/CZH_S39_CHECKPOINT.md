# CZH-S39 Checkpoint — Result Transport Flattening + Contract Locking

**Sprint:** CZH-S39  
**Batch:** CZH-B44  
**Gate:** CZH-GATE-98  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-931` through `CZH-940` were executed in strict order with one commit per ticket.
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no ticket/sprint lineage added to source comments
- widget remained integration facade while terminal-owned decision/fold semantics were preserved

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-931 | `ccac0976` | Transport audit + flattening map |
| CZH-932 | `01c48e58` | Authority tightening (doc-only) |
| CZH-933 | `1f159554` | Refresh transport flattening |
| CZH-934 | `0a3e1185` | Reuse transport flattening |
| CZH-935 | `279dd12c` | Direct-present transport flattening |
| CZH-936 | `917a89f7` | Widget/runtime boundary cleanup |
| CZH-937 | `705ed67e` | Helper-level invariants |
| CZH-938 | `877c5fcb` | Integration invariants |
| CZH-939 | `8d971f41` | Hygiene sweep |
| CZH-940 | (this commit) | Validation packet + gate handoff |

## Validation

### Required ladder

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `timeout 3s zig build run -- --mode terminal` — **PASS (bounded smoke; command exits by timeout as intended after startup banner)**
- `python3 ops/android_terminal_host.py deploy` — **PASS**
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — **PASS (no AndroidRuntime errors)**

## Key Changes (Behavior-Neutral)

### 1) Audit + authority alignment

- Added explicit S39 transport audit/execution map:
  - `docs/todo/core/CZH_931_TRANSPORT_AUDIT_FLATTENING_MAP.md`
- Tightened architecture authority for flattened transport edges and canonical fold exits:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`

### 2) Refresh transport flattening

- Added terminal helper `refreshedPresentationResultFromCycleTiming(...)` to centralize refresh timing carrier mapping.
- Widget refresh transport now uses canonical timing helper instead of duplicating timing field threading at callsites.

### 3) Reuse transport flattening

- Added terminal helper `foldReuseAttemptOutcome(...)` to centralize both reused and non-reused attempt folding into host-facing result transport.
- Widget reuse boundary now routes directly through terminal canonical reuse fold path (single route, no wrapper-level branch duplication).

### 4) Direct-present transport flattening

- Added terminal helper `directPresentTimingResult(...)` for direct timing carrier transport.
- Widget direct-present execution path now maps direct timing through canonical terminal helper before direct fold.

### 5) Boundary cleanup + invariants

- Removed/reduced redundant boundary transport glue in widget runtime where flattening made it unnecessary.
- Added helper-level invariants for:
  - refresh timing transport helper parity
  - reuse attempt fold helper parity
  - direct timing helper parity
- Added integration invariants to lock:
  - refresh timing helper transport parity
  - reuse flattened transport parity at widget/terminal boundary

### 6) Hygiene

- Completed hygiene sweep commit for touched seam set with no additional behavior/ABI changes.

## Board / Gate Notes

- Per board rules, movement into `review_gate`/`done` is Architect-owned.
- This document is the engineer gate packet for `CZH-GATE-98`.

## Files touched in this sprint window

- `docs/todo/core/CZH_931_TRANSPORT_AUDIT_FLATTENING_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
