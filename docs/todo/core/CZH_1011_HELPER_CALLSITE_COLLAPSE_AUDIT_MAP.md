# CZH-1011 Helper/Callsite Collapse Audit Map — Outcome/Transport Canonicalization

**Ticket:** `CZH-1011`  
**Sprint:** `CZH-S47`  
**Batch:** `CZH-B52`  
**Gate:** `CZH-GATE-106`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit remaining outcome/transport helper duplication and boundary callsite spread,
then define the execution cut map for `CZH-1012`..`CZH-1020`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited helper duplication

- Refresh/reuse/direct outcome paths still duplicate transport helper composition logic
  across classification + fold callsites.
- Canonical fold helpers exist per flow, but input transport helper shaping remains
  wider than necessary.

**Collapse target:** one canonical transport helper route per flow, with duplicated
helper composition removed.

## Audited boundary callsites

- Widget boundary still carries repeated terminal-runtime helper access patterns.
- Terminal fold callsites still contain repeated transport-field mapping at outcome fold points.

**Canonicalization target:** boundary callsites route through one canonical helper/callsite
path per flow with no duplicate mapping glue.

## Execution cut map (`CZH-1012`..`CZH-1020`)

1. `CZH-1012` — authority tightening for helper collapse + callsite canonicalization.
2. `CZH-1013` — refresh helper collapse cut.
3. `CZH-1014` — reuse helper collapse cut.
4. `CZH-1015` — direct helper collapse cut.
5. `CZH-1016` — widget callsite canonicalization cut.
6. `CZH-1017` — terminal callsite canonicalization cut.
7. `CZH-1018` — helper-level invariants for collapsed helper surface.
8. `CZH-1019` — integration invariants + hygiene sweep.
9. `CZH-1020` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/followup changes.
- No FFI export/symbol changes.

## Audit conclusion

`CZH-B51` contracted fold/result carriers and collapsed baseline boundary callsites.
`CZH-B52` removes remaining helper duplication and canonicalizes callsites to one
route per flow while preserving behavior and ABI stability.
