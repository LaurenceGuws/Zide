# CZH-1021 Fold-Entry/Field-Route Audit Map — Canonical Fold Entry Collapse

**Ticket:** `CZH-1021`  
**Sprint:** `CZH-S48`  
**Batch:** `CZH-B53`  
**Gate:** `CZH-GATE-107`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit remaining canonical fold-entry duplication and boundary field-route spread,
then define execution cuts for `CZH-1022`..`CZH-1030`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited fold-entry duplication

- Refresh/reuse/direct fold functions already converge on `presentResultFromOutcomeState`,
  but still replicate entry-shaping patterns at function boundaries.
- Canonical entrypoints exist; remaining work is collapsing repeated entry setup into
  one per-flow helper route.

**Collapse target:** one canonical fold-entry helper route per flow before generic fold.

## Audited boundary field-route spread

- Outcome structs currently carry both transport carrier and mirrored top-level fields.
- Consistency checks exist, but field-route lock assertions can be stronger at boundary helpers.

**Lock target:** explicit route-lock checks that boundary fold/helpers consume canonical
transport carrier routes and maintain mirrored-field consistency.

## Execution cut map (`CZH-1022`..`CZH-1030`)

1. `CZH-1022` — authority tightening for fold-entry collapse + field-route lock.
2. `CZH-1023` — refresh canonical fold-entry collapse cut.
3. `CZH-1024` — reuse canonical fold-entry collapse cut.
4. `CZH-1025` — direct canonical fold-entry collapse cut.
5. `CZH-1026` — refresh boundary field-route lock cut.
6. `CZH-1027` — reuse/direct boundary field-route lock cut.
7. `CZH-1028` — helper-level invariants for collapsed entries + locked routes.
8. `CZH-1029` — integration invariants + hygiene sweep.
9. `CZH-1030` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/followup changes.
- No FFI export/symbol changes.

## Audit conclusion

`CZH-B52` collapsed outcome/transport helper duplication and canonicalized boundary
callsites. `CZH-B53` now collapses remaining fold-entry setup and locks boundary
field routes to one canonical route per flow while preserving behavior and ABI.
