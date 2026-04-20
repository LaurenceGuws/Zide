# CZH-941 Transport Boundary Audit Map — Refresh/Reuse Transport Boundary Consolidation

**Ticket:** `CZH-941`  
**Sprint:** `CZH-S40`  
**Batch:** `CZH-B45`  
**Gate:** `CZH-GATE-99`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + consolidation execution map (no product behavior change)

---

## Purpose

This audit documents the remaining refresh/reuse transport boundary spread and
defines the bounded consolidation cuts for `CZH-942`..`CZH-950`.

S40 target remains explicit:

- **Terminal layer owns decision + fold semantics and canonical host-facing result transport.**
- **Widget layer remains integration facade (execution wiring + renderer/shell context only).**

---

## Hard constraints (normative)

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No ticket/sprint lineage in source comments.
- Widget remains integration facade; terminal owns decision/fold semantics.
- Keep transport routes single-path and contract-explicit.

---

## Audited boundary surfaces

### Terminal-owned canonical transport/fold (`src/terminal/presentation_runtime.zig`)

- `classifyRefreshOutcome(...)`
- `presentResultFromRefreshOutcomeState(...)`
- `checkReuseEligibility(...)`
- `foldReuseAttemptOutcome(...)`
- `presentResultFromReuseOutcomeState(...)`
- `presentResultFromOutcomeState(...)` (generic fold hub)
- `RefreshedPresentablePresentationResult`
- `refreshedPresentationResultFromCycleTiming(...)`

### Widget integration/runtime boundary (`src/ui/widgets/terminal_widget_presentation_runtime.zig`)

- `runPresentableRefreshCycle(...)`
- `runRefreshedPresentablePresentation(...)`
- `executeRefreshPresentFlow(...)`
- `tryFastPresentExisting(...)`
- `runFastPresentIfAvailable(...)`
- `runPresentation(...)` (top-level path convergence)

### Test lock surfaces

- `src/terminal/test_presentation_runtime.zig` (helper-level contracts)
- `src/ui/widgets/test_presentation_runtime_integration.zig` (integration parity)

---

## Current boundary spread (observed)

### Refresh boundary spread

Current refresh path is structurally correct but split across three seam steps:

1. Widget executes update cycle and returns refresh execution timing.
2. Widget computes present-state/attachment and returns refreshed presentation result carrier.
3. Terminal refresh orchestration folds refresh outcome and timing into host-facing result.

**Observation:** Semantics are terminal-owned, but refresh transport fields are still assembled
across multiple helper boundaries in widget integration.

**Consolidation pressure:** tighten refresh boundary so widget helper boundaries do not imply
alternate refresh transport ownership.

---

### Reuse boundary spread

Current reuse path:

1. Widget computes attachment + executes optional fast-present path (`tryFastPresentExisting`).
2. Reuse attempt outcome state returns from widget execution boundary.
3. Terminal fold helper produces host-facing result.

**Observation:** Transport is mostly flattened already via terminal fold helper, but boundary
contract can be tightened so reuse attempt/result handoff has one clearly sanctioned seam.

**Consolidation pressure:** preserve single fold path and prevent callsite-level divergence
for non-reused vs reused transport handling.

---

## Consolidation targets (S40)

### Target A — Refresh canonical boundary lock

- Keep widget refresh helpers execution-scoped.
- Keep terminal fold entry as the single canonical host-facing refresh transport edge.
- Avoid introducing any second refresh-result composition path in widget.

### Target B — Reuse canonical boundary lock

- Keep `tryFastPresentExisting(...)` as execution boundary only.
- Keep terminal reuse fold helper as the only host-facing result composition route.
- Ensure non-reused and reused attempts share one transport fold route.

### Target C — Boundary helper simplification

- Remove/merge redundant refresh/reuse transport helper glue where ownership is duplicated.
- Preserve behavior and existing runtime ordering.

### Target D — Contract invariants

- Add helper + integration tests that lock refresh/reuse boundary ownership and parity.
- Ensure no boundary re-derivation of terminal-owned outcome/fold semantics.

---

## Risks / anti-goals

### Risks if consolidation is not done

- Widget boundary appears to own transport semantics by accident.
- Future edits reintroduce duplicate refresh/reuse fold routes.
- Test coverage drifts from real ownership split.

### Explicit anti-goals

- No parser/protocol/terminal semantic changes.
- No renderer backend architecture changes.
- No host ABI/C export/interface changes.
- No compatibility shims or fallback branches.

---

## Planned ticket mapping (`CZH-942`..`CZH-950`)

- `CZH-942` — authority tightening (doc-only) for refresh/reuse boundary ownership.
- `CZH-943` — refresh transport boundary consolidation to canonical terminal-owned path.
- `CZH-944` — reuse transport boundary consolidation to canonical terminal-owned path.
- `CZH-945` — helper boundary simplification after consolidation (no behavior change).
- `CZH-946` — widget/runtime boundary cleanup to remove residual transport glue.
- `CZH-947` — helper invariants locking consolidated refresh/reuse boundary semantics.
- `CZH-948` — integration invariants locking parity and compatibility after consolidation.
- `CZH-949` — hygiene sweep (probe/debug residue + stale source comment wording in touched set).
- `CZH-950` — validation packet + gate handoff docs (`implementation`, checkpoint, board).

---

## Validation expectation for sprint close (`CZH-950`)

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- `timeout 3s zig build run -- --mode terminal`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

---

## Audit conclusion

S39 flattened major result transport routes; S40 should now consolidate remaining
refresh/reuse boundary spread into a stricter ownership picture:

- widget executes,
- terminal classifies/folds,
- host-facing transport exits through terminal canonical fold seams only.

This map is the execution authority for the S40 consolidation sequence.