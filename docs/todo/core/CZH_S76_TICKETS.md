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

### `CZH-1249` Bridge cache-invalidation helper consolidation

Scope: remove duplicate shell-surface cache invalidation/redraw helpers in Android bridge runtime flow.

Acceptance:
- one helper owns cache invalidation + redraw for equivalent callsites
- no behavior or ABI drift

### `CZH-1250` Product-fit dirty flag ownership consolidation

Scope: centralize `productGridFitDirty` mutation/read operations behind bridge-local owner helpers.

Acceptance:
- no ad-hoc flag writes at callsites
- dirty-flag ownership is explicit and test/build behavior remains unchanged

### `CZH-1251` Shared lifecycle extraction (surface-available logical pixels)

Scope: move platform-agnostic surface-available metric shaping from Android bridge into shared lifecycle runtime.

Acceptance:
- Android bridge no longer shapes default logical-pixel surface metrics inline
- shared owner has direct test coverage

### `CZH-1252` Geometry invalidation helper consolidation

Scope: unify repeated terminal presentation-geometry invalidation + redraw request logic into one bridge-local helper.

Acceptance:
- duplicate invalidation/redraw blocks removed
- no behavior/ABI drift

### `CZH-1253` Bridge API ownership audit cut

Scope: convert focused bridge API audit into at least one executable ownership reduction, then map next bounded tickets.

Acceptance:
- one duplicate ownership seam removed in code
- next two bounded tickets identified for continuation without doc-only drift

### `CZH-1254` Renderer query fallback helper consolidation

Scope: reduce repeated null-check fallback logic across renderer status query functions in Android bridge.

Acceptance:
- fallback behavior unchanged
- query ownership code is less duplicated and easier to audit

### `CZH-1255` Phase-2 closure extraction or explicit no-op proof

Scope: either extract one final platform-agnostic lifecycle/presentation primitive into shared owner or close phase with explicit proof that further extraction is non-beneficial.

Acceptance:
- one bounded extraction or explicit closure proof with callsite references
- queue ready for next primary goal transition
