# CZH-1051 Route/Assertion Minimization Audit Map

**Ticket:** `CZH-1051`  
**Sprint:** `CZH-S51`  
**Batch:** `CZH-B56`  
**Gate:** `CZH-GATE-110`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit fold transport routes and assertion surface after `CZH-B55` assertion collapse,
then define execution cuts for `CZH-1052`..`CZH-1060`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited transport route paths

### Current state

- Outcome classification creates outcome structs with transport carriers.
- Fold functions call `presentResultFromOutcomeState()` with outcome transport fields.
- Each outcome type has separate classification + fold path.
- Some intermediate computations may be redundant or simplifiable.

**Route patterns:**

Refresh: `classifyRefreshOutcome()` → `foldRefreshOutcomeToPresent()` → `presentResultFromOutcomeState()`  
Reuse: `reuseSuccessOutcome()` → `foldReuseOutcomeToPresent()` → `presentResultFromOutcomeState()`  
Direct: `classifyDirectPresentOutcome()` → `foldDirectOutcomeToPresent()` → `presentResultFromOutcomeState()`

**Pruning target:** eliminate unnecessary intermediate steps; direct field mapping where possible without loss of invariant verification.

## Audited assertion surface

### Current state

- Each outcome type has `assertXOutcomeConsistency()` checking outcome-type-specific invariants.
- Helper-level invariants check transport threading through fold.
- Some assertions may be redundant given construction invariants.

**Assertion patterns:**

- Refresh: followup consistency check
- Reuse: success invariants (if .reused then all fields true)
- Direct: cache/renderer/conjunction invariants

**Minimization target:** remove assertions that are guaranteed by construction; keep only invariants that catch runtime anomalies.

## Execution cut map (`CZH-1052`..`CZH-1060`)

1. `CZH-1052` — authority tightening for route pruning + assertion minimization.
2. `CZH-1053` — refresh transport route pruning cut.
3. `CZH-1054` — reuse transport route pruning cut.
4. `CZH-1055` — direct transport route pruning cut.
5. `CZH-1056` — refresh assertion-surface minimization cut.
6. `CZH-1057` — reuse/direct assertion-surface minimization cut.
7. `CZH-1058` — helper-level invariants for pruned routes + minimal assertions.
8. `CZH-1059` — integration invariants + hygiene sweep.
9. `CZH-1060` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/followup changes.
- No FFI export/symbol changes.
- No behavioral changes to result composition.

## Audit conclusion

`CZH-B55` collapsed assertions and simplified mappings. `CZH-B56` now prunes unnecessary
transport routes and minimizes assertion surface to essential invariants only while preserving
behavior and ABI.
