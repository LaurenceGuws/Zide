# `CZH-S26` Tickets — long-loop surface/result contraction follow-through

Sprint: `CZH-S26`  
Authority parent: accepted reporting/result seam contraction (`CZH-B30`)  
Super-gate: `CZH-GATE-85`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze by default; any behavior fix must be isolated, justified, and explicitly marked in queue docs.
- No host ABI/C export changes in this sprint.
- No early architect bounce: continue through `CZH-810` unless a real hard blocker appears.

## Ticket list

### `CZH-801` Follow-through audit + hygiene scope
- Map remaining duplicated present/report derivation callsites after `CZH-S25`.
- Record explicit behavior-freeze guardrails for this sprint and `CZH-809` scope.

### `CZH-802` Tighten docs for single derivation story
- Align touched module/function docs to one canonical derivation story per flow.
- Docs/comments only.

### `CZH-803` Runtime callsite contraction pass
- Contract selected runtime callsites to canonical helpers where still duplicated.
- Preserve behavior.

### `CZH-804` Surface-state/read bridge contraction pass
- Contract selected bridge callsites and remove parallel equivalent derivations.
- Preserve behavior.

### `CZH-805` Present-result fold cohesion pass
- Align selected fold paths to canonical leg/conjunction route without changing struct ABI.
- Preserve behavior.

### `CZH-806` Widget/draw ownership wording pass
- Keep widget/draw ownership comments aligned after contraction.
- Docs/comments and naming only.

### `CZH-807` Helper-level equivalence tests
- Add/extend helper tests that lock canonical-vs-legacy equivalence for touched seams.

### `CZH-808` Integration equivalence tests
- Add/extend integration tests locking runtime/state/result cohesion for touched flows.

### `CZH-809` Scoped probe/doc hygiene sweep + authority sync
- Remove stale investigation-only probe/debug residue in touched files.
- Record removed/kept signals and rationale in queue.

### `CZH-810` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S26_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-85`.
