# CZH-931 Transport Audit + Flattening Map — Result Transport Flattening + Contract Locking

**Ticket:** `CZH-931`  
**Sprint:** `CZH-S39`  
**Batch:** `CZH-B44`  
**Gate:** `CZH-GATE-98`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit and execution map only

---

## Purpose

Document the current result transport surfaces across terminal/widget presentation runtime seams, identify remaining transport indirections, and define the flattening/contract-lock targets for `CZH-932`..`CZH-940`.

This audit establishes the authoritative S39 transport goal:

- **Terminal layer owns decision/fold semantics and canonical result transport.**
- **Widget layer remains integration facade and execution owner only.**

---

## Hard constraints (normative)

- Behavior freeze; no semantic behavior change.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No ticket/sprint lineage in product source comments.
- Widget remains integration facade; terminal owns decision/fold semantics.
- Keep changes single-path and contract-explicit.

---

## Audited seam inventory

### Terminal-owned canonical result carriers (`src/terminal/presentation_runtime.zig`)

- `RefreshOutcomeState`
- `ReusePresentOutcomeState`
- `DirectPresentOutcomeState`
- `RefreshedPresentablePresentationResult`
- Fold outputs via host-facing `TerminalPresentResult`

### Terminal-owned canonical fold/classification routes

- `classifyRefreshOutcome(...)`
- `classifyDirectPresentOutcome(...)`
- `reuseSuccessOutcome()`
- `presentResultFromRefreshOutcomeState(...)`
- `presentResultFromReuseOutcomeState(...)`
- `presentResultFromDirectPresentOutcomeState(...)`
- `presentResultFromOutcomeState(...)` (generic fold hub)

### Widget integration/runtime seam (`src/ui/widgets/terminal_widget_presentation_runtime.zig`)

- `runPresentableRefreshCycle(...)` -> refresh-cycle execution carrier
- `runRefreshedPresentablePresentation(...)` -> refreshed presentation carrier
- `executeRefreshPresentFlow(...)` -> terminal orchestrator entry for refresh path
- `tryFastPresentExisting(...)` + `runFastPresentIfAvailable(...)` -> reuse path wrapper
- `directPresent(...)` -> direct draw execution carrier
- `executePresentableUpdate(...)` / `tryIncrementalPresentableUpdate(...)` -> update/partial execution carriers

### Existing test-lock surfaces

- Helper invariants: `src/terminal/test_presentation_runtime.zig`
- Integration invariants: `src/ui/widgets/test_presentation_runtime_integration.zig`

---

## Observed remaining result-transport indirections

### Indirection A — Widget-local execution result carriers duplicate timing transport shape
Current widget-local carriers:
- `DirectPresentResult`
- `IncrementalPresentableUpdateResult`
- `PresentationExecutionResult`

These are useful for execution internals but partially overlap canonical timing/result transport concerns.

**Risk:** Transport shape drift between internal execution carriers and canonical folded carriers.

**Flattening target:** Reduce duplicated transport handoff points by tightening conversion boundaries and routing canonical fold transport at single seam exits.

---

### Indirection B — Refresh path still traverses two result carrier layers before fold
Current path:
1. refresh execution result
2. refreshed presentation result
3. refresh outcome classification/fold

This layering is valid, but transport edges can be tightened so each handoff has one clear owner and no duplicate semantics.

**Risk:** Contract ambiguity over where timing/attachment fields become authoritative.

**Flattening target:** Keep execution-owned carriers execution-local; make terminal fold entry the explicit canonical transport boundary.

---

### Indirection C — Reuse path transport split between outcome-state constructor and wrapper return
Current path:
- `tryFastPresentExisting(...)` returns `ReusePresentOutcomeState`
- wrapper checks result condition and folds

This is already mostly clean; remaining work is contract-locking that this is the only reuse result transport path.

**Risk:** Future ad-hoc wrapper helpers reintroducing alternate reuse transport routes.

**Flattening target:** Lock single reuse transport route via helper + integration invariants.

---

### Indirection D — Direct path timing transport assembled via execution result then canonical fold
Current path:
- direct execution returns widget-local timing carrier
- classification + canonical direct fold produce host-facing result

This is acceptable, but contract should explicitly lock that fold is the only host-facing direct transport exit.

**Risk:** future direct-path callsites bypass canonical direct fold helper.

**Flattening target:** strengthen contract/tests ensuring no alternate direct host-result composition paths.

---

## Contract edges to lock in S39

### Edge 1 — Terminal fold ownership
All host-facing result composition must terminate in terminal-owned fold helpers.

### Edge 2 — Widget execution ownership
Widget may own GPU draw/update execution carriers, but must not own semantic result composition.

### Edge 3 — Refresh attachment/report cohesion
Refresh conjunction transport remains inline in refresh outcome carrier; no split fold argument route reintroduced.

### Edge 4 — Reuse canonical success signal
Reuse success remains canonicalized to `outcome == .reused`; no extra success flags reintroduced.

### Edge 5 — Direct canonical fold route
Direct host-facing result path must go through `presentResultFromDirectPresentOutcomeState(...)`.

---

## Planned flattening cuts mapped to ticket sequence

- `CZH-932` — Authority tightening (doc-only): align architecture docs with flattened transport ownership and contract edges.
- `CZH-933` — Refresh transport flattening: reduce refresh transport indirections at boundary handoff seams while preserving semantics.
- `CZH-934` — Reuse transport flattening: lock single reuse transport path and remove residual wrapper indirections.
- `CZH-935` — Direct-present transport flattening: lock direct host-result path to canonical direct fold seam.
- `CZH-936` — Widget/runtime boundary cleanup: remove redundant transport glue left after flattening.
- `CZH-937` — Helper-level invariants: lock flattened transport semantics in terminal helper tests.
- `CZH-938` — Integration invariants: lock widget/terminal transport parity and no re-derivation at boundary.
- `CZH-939` — Hygiene sweep: remove stale probe/debug residue and stale source-comment phrasing in touched files.
- `CZH-940` — Validation packet + gate handoff.

---

## Explicit non-goals

- No renderer/backend architecture redesign.
- No terminal semantic behavior change.
- No host ABI/C export/interface changes.
- No compatibility branch introduction.
- No ticket history in product source comments.

---

## Validation expectation for batch closure (`CZH-940`)

Required ladder:

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- `timeout 3s zig build run -- --mode terminal`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

---

## Audit conclusion

The S38 carrier simplification established strong terminal-owned fold/classification routes.  
S39 should now flatten remaining result transport indirections at execution-to-fold boundaries and lock those edges with helper/integration invariants so terminal result transport remains single-path, explicit, and behavior-neutral.