# CZH-981 Fold-Route/Field Contraction Audit Map — Boundary Fold Unification

**Ticket:** `CZH-981`  
**Sprint:** `CZH-S44`  
**Batch:** `CZH-B49`  
**Gate:** `CZH-GATE-103`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime semantic or ABI change)

## Purpose

Audit remaining boundary fold-route naming split and duplicated transport-field
shapes, then define execution cuts for `CZH-982`..`CZH-990`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited fold-route split

- Refresh fold route currently exposed as `foldRefreshOutcomeToPresent(...)`.
- Reuse fold route currently exposed as `foldReuseOutcomeToPresent(...)`.
- Direct fold route currently exposed as `foldDirectOutcomeToPresent(...)`.

All three route through canonical generic folding in terminal runtime; remaining
work is naming/entrypoint unification evidence and helper-level lock coverage.

## Audited transport-field duplication

- Refresh/reuse/direct fold routes all carry outcome/cache/host-target/attachment
  fields into `TerminalPresentResult`.
- Refresh also carries followup transport; this is now a contracted nested field
  on the refresh outcome carrier.
- Remaining duplication is route-local field threading shape, not behavior.

## Execution cut map (`CZH-982`..`CZH-990`)

1. `CZH-982` authority tightening for unified fold-route and field-contraction story.
2. `CZH-983` refresh fold-route unification cut.
3. `CZH-984` reuse fold-route unification cut.
4. `CZH-985` direct-present fold-route unification cut.
5. `CZH-986` refresh transport-field contraction cut.
6. `CZH-987` reuse/direct transport-field contraction cut.
7. `CZH-988` helper-level invariants for unified fold routes.
8. `CZH-989` integration invariants + hygiene sweep.
9. `CZH-990` full ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend refactor.
- No terminal feature behavior change.
- No FFI export/symbol changes.

## Audit conclusion

The runtime already enforces canonical single-path folding. `CZH-B49` narrows
remaining route naming and duplicated transport-field threading to one canonical
shape per flow while preserving behavior and ABI.
