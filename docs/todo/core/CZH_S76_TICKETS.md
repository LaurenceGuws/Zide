# CZH-S76 Tickets - Android-to-Core Consolidation (Phase 2)

Sprint: `CZH-S76`
Batch: `CZH-B81`
Gate: `CZH-GATE-135`
Focus: remove remaining Android-specialized ownership residue around host lifecycle/presentation seams and keep Android bridge code as a thin platform shell.

## Execution Rules

- Code/test movement is mandatory for implementation tickets.
- At most one architect-approved `doc-only` ticket is allowed if needed to map an extraction cut.
- No behavior or ABI changes unless a correctness bug is found and explicitly scoped.
- No Android feature expansion in this sprint.
- Keep cuts bounded and reviewable; no broad subsystem rewrites.

## Tickets

### `CZH-1245` Residual wrapper cleanup (platform lifecycle seam)

Scope: remove or justify residual Android lifecycle helper wrappers now that shared lifecycle runtime owner exists.

Acceptance:
- wrapper ownership is unambiguous
- dead or duplicate wrapper logic removed
- callsites route through shared owner directly

### `CZH-1246` Shared lifecycle API normalization

Scope: normalize shared lifecycle helper naming and callsite phrasing so API names reflect ownership, not caller context.

Acceptance:
- no caller-specific naming residue in shared owner surface
- input/bridge callsites remain behavior-neutral
- tests remain green

### `CZH-1247` Android bridge thinning cut

Scope: extract one shared runtime/presentation operation from `android_runtime_bridge.zig` into a shared seam so Android bridge remains platform shell plus glue only.

Acceptance:
- one bounded extraction with explicit owner
- no behavior/ABI drift
- Android bridge file loses one platform-agnostic responsibility

### `CZH-1248` Validation packet + completion handoff

Scope: run validation ladder and publish completion state for active mode.

Acceptance:
- validation result recorded as a short note in `docs/todo/core/ACTIVE_QUEUE.md`
- handoff still points at the next real product focus
