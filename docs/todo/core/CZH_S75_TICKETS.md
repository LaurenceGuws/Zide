# CZH-S75 Tickets - Android-to-Core Consolidation (Kickoff)

Sprint: `CZH-S75`
Batch: `CZH-B80`
Gate: `CZH-GATE-134`
Focus: consolidate Android-proven renderer/runtime seams into shared core ownership so Android stops carrying special-case gravity.

## Execution Rules

- Code/test movement is mandatory for implementation tickets.
- At most one architect-approved `doc-only` mapping ticket is allowed to define concrete executable targets.
- No behavior or ABI changes unless a correctness bug is found and explicitly scoped.
- No Android-only workaround layering when the contract is shared by terminal/editor runtime seams.
- Keep cuts bounded and reviewable; no broad subsystem reshuffle in one ticket.

## Tickets

### `CZH-1241` Android-to-core seam map (`doc-only`, architect-approved)

Scope: identify concrete Android-specialized seams that should become shared-core ownership, with exact file/function target list and non-goals.

Acceptance:
- names exact executable follow-up targets for `CZH-1242` and `CZH-1243`
- classifies each target as shared-contract vs Android-owned
- no speculative rewrite plan

### `CZH-1242` First consolidation cut (shared contract extraction)

Scope: move one bounded Android-proven runtime/presentation contract from Android-local phrasing to shared core seam ownership.

Acceptance:
- code/test movement required
- behavior-neutral
- no compatibility shim residue

### `CZH-1243` Second consolidation cut (callsite + ownership cleanup)

Scope: remove one remaining Android-specialized callsite path where shared seam ownership is now available.

Acceptance:
- code/test movement required
- ownership is explicit at callsites
- no Android-only duplication retained

### `CZH-1244` Regression lock + gate handoff

Scope: validate consolidated seams, update owning docs, and move board to completion state for the active session mode.

Acceptance:
- validation ladder recorded in `docs/todo/core/implementation.md`
- board updated to mode-appropriate completion state (`review_gate` in dual mode, `done` in single mode)
- no dual-mode-only review wording when running single mode
