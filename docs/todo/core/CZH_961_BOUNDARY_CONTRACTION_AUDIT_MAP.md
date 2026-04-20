# CZH-961 Boundary Helper Contraction Audit Map — Refresh/Reuse Result Narrowing

**Ticket:** `CZH-961`  
**Sprint:** `CZH-S42`  
**Batch:** `CZH-B47`  
**Gate:** `CZH-GATE-101`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit and cut map only (no runtime behavior/ABI change)

---

## Purpose

Audit remaining refresh/reuse helper wrapper duplication and result-carrier widening,
then define the implementation cut map for `CZH-962`..`CZH-970`.

S42 objective:

- contract helper wrappers to one canonical terminal-owned fold route per boundary
- narrow refresh/reuse boundary carriers to canonical folded host-facing result terms
- keep widget as integration facade and terminal as decision/fold owner

---

## Hard constraints (normative)

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue in touched files.
- Source comments remain present-tense architecture only.

---

## Audited duplication and widening map

### Refresh-side helper duplication

1. `src/terminal/presentation_runtime.zig`
   - `refreshedPresentationResultFromCycle(...)` wraps
     `classifyRefreshOutcome(...)` + `presentResultFromRefreshOutcomeState(...)`
     into a single-field carrier.
2. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
   - `runRefreshBoundaryPresentationResult(...)` performs boundary execution and
     returns the terminal wrapper carrier.

**Contraction target:** one canonical fold helper route remains explicit at
terminal layer (`presentResultFromRefreshOutcomeState`); wrapper chaining is removed.

### Reuse-side helper duplication

1. `src/terminal/presentation_runtime.zig`
   - `foldReuseAttemptOutcome(...)` and `foldReuseAttemptResultToPresent(...)`
     are stacked wrappers over the same fold logic.
   - `presentResultFromReuseOutcomeState(...)` is an alias wrapper over
     `foldReuseAttemptResultToPresent(...)`.
2. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
   - `runFastPresentIfAvailable(...)` wraps `tryFastPresentExisting(...)` and
     only folds the outcome carrier.

**Contraction target:** one canonical terminal fold helper for reuse transport;
widget boundary does not keep wrapper-only fold hops.

### Refresh/reuse carrier widening

1. Refresh boundary currently threads
   `RefreshedPresentablePresentationResult { present_result: TerminalPresentResult }`.
2. Reuse boundary currently threads
   `ReusePresentOutcomeState` across widget helper boundary, then folds later.

**Narrowing target:** refresh/reuse boundary return surfaces carry
`TerminalPresentResult` directly after terminal-owned folding.

---

## Execution cut map (`CZH-962`..`CZH-970`)

1. `CZH-962` — tighten authority docs to the contracted helper/narrowed-carrier story.
2. `CZH-963` — refresh helper contraction (remove refresh-side wrapper duplication).
3. `CZH-964` — reuse helper contraction (remove reuse-side wrapper duplication).
4. `CZH-965` — refresh boundary result narrowing to folded host-facing result carrier.
5. `CZH-966` — reuse boundary result narrowing to folded host-facing result carrier.
6. `CZH-967` — widget/runtime boundary cleanup after helper/result contraction.
7. `CZH-968` — helper-level invariants for canonical helper routes and narrowed carriers.
8. `CZH-969` — integration invariants + touched-file hygiene sweep.
9. `CZH-970` — validation ladder, checkpoint packet, board transition to gate handoff.

---

## Non-goals

- No terminal semantic behavior changes.
- No C export/ABI changes.
- No broad renderer or platform refactor.

---

## Validation expectation at gate (`CZH-970`)

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- `timeout 3s zig build run -- --mode terminal`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

---

## Audit conclusion

S41 removed alias vocabulary drift. S42 now contracts remaining helper wrappers
and narrows refresh/reuse boundary result carriers so boundaries expose only
canonical folded host-facing transport semantics while preserving behavior and ABI.
