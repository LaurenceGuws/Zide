# CZH-991 Fold API/Field-Shape Audit Map — Terminal/Widget Fold API Narrowing

**Ticket:** `CZH-991`  
**Sprint:** `CZH-S45`  
**Batch:** `CZH-B50`  
**Gate:** `CZH-GATE-104`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit remaining terminal/widget fold API surface width and field-shape drift risks,
then define the implementation cut map for `CZH-992`..`CZH-1000`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited fold API width

- Canonical fold routes are now named consistently:
  - `foldRefreshOutcomeToPresent(...)`
  - `foldReuseOutcomeToPresent(...)`
  - `foldDirectOutcomeToPresent(...)`
- Generic fold support APIs still present broad call surfaces that are not required at
  terminal/widget integration boundary.

**Narrowing target:** runtime/widget callers use only canonical per-flow fold routes;
generic composition helpers are kept internal to terminal runtime.

## Audited field-shape drift risk

- `RefreshOutcomeState` now carries nested `followup` shape, but lock coverage is still
  mostly behavior assertions and not explicit shape guardrails.
- Shared fold transport payload uses `FoldTransportFields`; lock coverage should verify
  field-shape stability explicitly at helper + integration levels.

**Lock target:** explicit invariant coverage for canonical outcome/transport field shapes
and no duplicate mapping helpers at widget boundary.

## Execution cut map (`CZH-992`..`CZH-1000`)

1. `CZH-992` — authority tightening for narrowed fold API and locked field-shape contract.
2. `CZH-993` — refresh fold API narrowing cut.
3. `CZH-994` — reuse fold API narrowing cut.
4. `CZH-995` — direct fold API narrowing cut.
5. `CZH-996` — refresh/reuse field-shape lock cut.
6. `CZH-997` — direct field-shape lock cut.
7. `CZH-998` — helper-level invariants for narrowed API + locked field shapes.
8. `CZH-999` — integration invariants + hygiene sweep.
9. `CZH-1000` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No render backend refactor.
- No semantic result/followup behavior changes.
- No FFI export/symbol changes.

## Audit conclusion

`CZH-B49` unified fold-route naming and contracted transport fields. `CZH-B50` narrows
the exposed fold API surface to canonical per-flow routes and locks field shapes so
transport semantics remain single-path and behavior-neutral.
