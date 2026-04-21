# CZH-S74 Tickets - Naming and Module Topology Normalization

Sprint: `CZH-S74`
Batch: `CZH-B79`
Gate: `CZH-GATE-133`
Focus: normalize naming and module boundaries in `src/ui/widgets/` so extraction to dedicated repos remains feasible and low-risk.

## Execution Rules

- Code/test movement is mandatory for implementation tickets.
- Exactly one architect-approved `doc-only` ticket is allowed in this sprint (`CZH-1235`) to lock concrete rename/move scope.
- Do not reopen phase-1 hygiene hunting unless a concrete regression is found.
- No behavior or ABI changes unless a correctness bug is found and explicitly recorded.
- Keep diffs reviewable; avoid broad move-only churn without corresponding ownership clarity gains.

## Tickets

### `CZH-1235` Widget naming/topology cut map (`doc-only`, architect-approved)

Scope: inventory `src/ui/widgets/` and define the first bounded rename/topology cuts with exact file/symbol targets and non-goals.

Acceptance:
- names concrete files and symbols
- defines first two code cuts for `CZH-1236` and `CZH-1237`
- no speculative full-folder migration plan

Architect result:
- Accepted after import-site scope correction.
- Output authority: `docs/todo/core/CZH_1235_WIDGET_NAMING_TOPOLOGY_MAP.md`.

### `CZH-1236` First naming normalization cut (terminal widget path)

Scope: land one bounded naming cleanup in terminal widget runtime/draw/input path, replacing ambiguous or sentence-like identifiers with concise ownership names.

Acceptance:
- code/test movement required
- preserves behavior and ABI
- updates only directly affected docs/comments

### `CZH-1237` Second naming normalization cut (editor/widget shared surface)

Scope: land one bounded naming cleanup in editor/widget shared seams.

Acceptance:
- code/test movement required
- no unrelated refactor expansion
- naming reflects ownership and role clearly

### `CZH-1238` First topology normalization cut (small, behavior-neutral)

Scope: one bounded module boundary cleanup in `src/ui/widgets/` (split or relocate a tightly scoped concern) aligned with `CZH-1235` map.

Acceptance:
- code/test movement required
- no behavior/ABI drift
- no broad folder reshuffle

### `CZH-1239` Regression lock + callsite cleanup for renamed/moved seams

Scope: lock renamed/moved seams with tests and remove any transitional ambiguity at callsites.

Acceptance:
- executable checks updated for renamed/moved seams
- no compatibility shim residue retained

### `CZH-1240` Validation packet + gate handoff

Scope: run validation ladder, publish sprint checkpoint, and move board to `review_gate`.

Acceptance:
- records validation in `docs/todo/core/implementation.md`
- updates board state only to `review_gate`
- does not mark architect acceptance
