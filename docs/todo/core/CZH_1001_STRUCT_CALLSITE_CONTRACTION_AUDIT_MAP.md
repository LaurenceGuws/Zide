# CZH-1001 Struct/Callsite Contraction Audit Map — Fold/Result Surface Narrowing

**Ticket:** `CZH-1001`  
**Sprint:** `CZH-S46`  
**Batch:** `CZH-B51`  
**Gate:** `CZH-GATE-105`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit remaining fold/result struct width and boundary callsite duplication, then
define the cut sequence for `CZH-1002`..`CZH-1010`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited struct width

- `RefreshOutcomeState`, `ReusePresentOutcomeState`, and `DirectPresentOutcomeState`
  still expose per-field transport members directly.
- Canonical fold transport already has `FoldTransportFields`; outcome structs can be
  contracted around this shared carrier without behavior change.

**Contraction target:** outcome structs carry canonical transport fields through one
contained shape per flow, reducing duplicate field threading.

## Audited boundary callsites

- Widget and terminal layers still contain repeated canonical fold invocations with
  similar callsite patterns.
- Canonical routes exist, but callsite surfaces remain wider than required.

**Collapse target:** one canonical callsite route per flow at widget and terminal
boundaries, with duplicate mapping hops removed.

## Execution cut map (`CZH-1002`..`CZH-1010`)

1. `CZH-1002` — authority tightening for contracted struct/callsite surface.
2. `CZH-1003` — refresh result-struct contraction cut.
3. `CZH-1004` — reuse result-struct contraction cut.
4. `CZH-1005` — direct result-struct contraction cut.
5. `CZH-1006` — widget boundary callsite collapse cut.
6. `CZH-1007` — terminal boundary callsite collapse cut.
7. `CZH-1008` — helper-level invariants for contracted struct/callsite surface.
8. `CZH-1009` — integration invariants + hygiene sweep.
9. `CZH-1010` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend refactor.
- No semantic outcome/followup behavior changes.
- No FFI export/symbol changes.

## Audit conclusion

`CZH-B50` narrowed fold API exposure and locked field shapes. `CZH-B51` contracts
remaining fold/result structs and collapses boundary callsites so routing remains
canonical, single-path, and behavior-neutral.
