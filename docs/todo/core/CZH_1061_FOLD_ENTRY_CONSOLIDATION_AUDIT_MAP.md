# CZH-1061 Canonical Fold-Entry Consolidation Audit Map

**Ticket:** `CZH-1061`  
**Sprint:** `CZH-S52`  
**Batch:** `CZH-B57`  
**Gate:** `CZH-GATE-111`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + callsite map only (no runtime behavior/ABI change)

## Purpose

Audit fold-entry callsites across presentation paths (refresh/reuse/direct), enumerate 
alias/helper indirection, and define consolidation routes for `CZH-1063`..`CZH-1065`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited fold-entry callsites

### Current state

Widget layer (`src/ui/widgets/terminal_widget_presentation_runtime.zig`):
- Imports three fold functions via const alias (lines 135-137):
  ```zig
  const foldRefreshOutcomeToPresent = terminal_presentation_runtime.foldRefreshOutcomeToPresent;
  const foldReuseOutcomeToPresent = terminal_presentation_runtime.foldReuseOutcomeToPresent;
  const foldDirectOutcomeToPresent = terminal_presentation_runtime.foldDirectOutcomeToPresent;
  ```

**Refresh path callsite:**
- Location: `terminal_widget_presentation_runtime.zig:924`
- Pattern: `classifyRefreshOutcome()` → `foldRefreshOutcomeToPresent(outcome, timing)`
- Context: executeRefreshCycleFlow, returns TerminalPresentResult
- Outcome type: RefreshOutcomeState (transport + followup)

**Reuse path callsite:**
- Location: `terminal_widget_presentation_runtime.zig:1428`
- Pattern: `reuseSuccessOutcome()` or manual construction → `foldReuseOutcomeToPresent(outcome, timing)`
- Context: tryFastPresentExisting, returns TerminalPresentResult
- Outcome type: ReusePresentOutcomeState (transport only)

**Direct path callsite:**
- Location: `terminal_widget_presentation_runtime.zig:1236`
- Pattern: `classifyDirectPresentOutcome()` → `foldDirectOutcomeToPresent(outcome, timing)`
- Context: executeDirectPresentFlow, returns TerminalPresentResult
- Outcome type: DirectPresentOutcomeState (transport only)

Terminal runtime (`src/terminal/presentation_runtime.zig`):
- Three public fold functions defined as canonical entry points:
  - `foldRefreshOutcomeToPresent(outcome, timing)` - line 148
  - `foldReuseOutcomeToPresent(outcome, timing)` - line 161
  - `foldDirectOutcomeToPresent(outcome, timing)` - line 186
- All three route through `presentResultFromOutcomeState(transport, timing)`

### Alias/indirection analysis

1. **Const alias import in widget:** Three fold functions are imported via const alias (lines 135-137).
   - These are thin passthrough aliases, not logical consolidation points.
   - Consolidation target: remove aliases; call terminal runtime functions directly.

2. **Outcome state as intermediate carrier:** Outcome structs (RefreshOutcomeState, etc.)
   are created at classification time and passed to fold functions.
   - RefreshOutcomeState carries: transport + followup
   - ReusePresentOutcomeState: transport only
   - DirectPresentOutcomeState: transport only
   - Consolidation target: fold classification and outcome construction into single entry.

3. **Classification + fold pattern repeats per flow:**
   - Each path does: classify → construct outcome → fold → return result
   - Consolidation target: one canonical terminal entry per flow that takes classification inputs directly

## Consolidation target routes

**Refresh consolidation (CZH-1063):**
- Widget calls new canonical: `presentation_runtime.refreshPresentEntry(refresh, attachment_ready, timing)`
- Terminal defines: takes classification inputs, constructs outcome, folds, returns result
- Removes: widget-side outcome construction, RefreshOutcomeState visibility at boundary

**Reuse consolidation (CZH-1064):**
- Widget calls new canonical: `presentation_runtime.reusePresentEntry(outcome, timing)` 
  (or variant for success vs non-reused)
- Terminal defines: constructs outcome from parameters, folds, returns result
- Removes: ReusePresentOutcomeState visibility at boundary, manual outcome threading

**Direct consolidation (CZH-1065):**
- Widget calls new canonical: `presentation_runtime.directPresentEntry(updated, timing)`
- Terminal defines: takes updated flag, constructs outcome, folds, returns result
- Removes: widget-side outcome construction, DirectPresentOutcomeState visibility at boundary

## Helper indirection eliminated

- Const aliases (lines 135-137): remove, call terminal directly
- Outcome intermediate carriers: encapsulated in terminal canonical entries
- Widget layer becomes pure facade: gathers input, calls canonical terminal entry, interprets result

## Execution cut map (`CZH-1062`..`CZH-1068`)

1. `CZH-1062` — Authority tightening (doc-only).
2. `CZH-1063` — Refresh flow consolidation cut.
3. `CZH-1064` — Reuse flow consolidation cut.
4. `CZH-1065` — Direct flow consolidation cut.
5. `CZH-1066` — Boundary struct/threading contraction.
6. `CZH-1067` — Helper + integration invariants lock.
7. `CZH-1068` — Hygiene sweep + validation packet + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/timing changes.
- No FFI export/symbol changes.
- No behavioral changes to result composition.

## Audit conclusion

Widget layer currently calls three terminal fold functions directly via const alias,
constructing outcome states as intermediate carriers. Consolidation goal: create one 
canonical terminal entry point per flow that takes classification inputs, constructs 
outcome internally, folds, and returns result — making widget purely a facade that 
doesn't manipulate outcome state structures.
