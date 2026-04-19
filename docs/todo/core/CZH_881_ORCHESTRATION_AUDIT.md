# CZH-881: Orchestration Boundary Audit + Cut Map

**Status:** `in_progress`  
**Scope:** Map pure orchestration helpers still in widget runtime and lock move order.  
**Authority:** CZH-S34 sprint, terminal runtime ownership completion.

## Boundary Definition

**Terminal-owned orchestration helpers** are functions that:
- Coordinate presentation flow decisions (refresh → outcome → fold → report)
- Never depend on renderer/shell state
- Never depend on widget-specific integration
- Operate on logical presentation state only
- Are callable from pure computation paths

**Widget-retained functions** are those that:
- Integrate with renderer/shell/input systems
- Manage UI-specific state (blink, sampling, input windows)
- Handle drawing/present execution (GPU operations)
- Depend on live renderer/shell pointers

## Current State (CZH-S33 completion)

Terminal layer owns:
- Outcome classification: `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()`, `reuseSuccessOutcome()`
- Outcome folding: `presentResultFromRefreshOutcomeState()`, etc.
- Hardening assertions: `assertRefreshOutcomeConsistency()`, etc.
- Geometry: `PresentationGeometry`, `computePresentationSurfaceGeometry()`
- Attachment state: `computeHostSurfaceAttachmentState()`

Widget layer still owns (pending extraction):
- `runPresentableRefreshCycle()` — coordinator for refresh cycle (outcome path)
- `runRefreshedPresentablePresentation()` — orchestrates after refresh decision
- `executeRefreshPresentFlow()` — main refresh flow driver
- `directPresent()` — direct present orchestration
- `tryFastPresentExisting()` — reuse decision coordinator
- `runFastPresentIfAvailable()` — reuse wrapper
- `runPresentation()` — top-level presentation orchestrator
- `refreshPresentState()` — present-state refresh coordinator
- `planUpdate()` — surface update planning

## Extraction Dependency Order

Extraction must respect flow order (deeper dependencies first):

### Phase 1: Outcome-path orchestration (CZH-883 Refresh-cycle cut A)
1. `runPresentableRefreshCycle()` — pure refresh orchestration, no renderer ops
2. `runRefreshedPresentablePresentation()` — outcome→fold→result pipeline
3. `executeRefreshPresentFlow()` — refresh driver

Dependencies on terminal layer:
- Uses: `classifyRefreshOutcome()`, `presentResultFromRefreshOutcomeState()`
- No renderer/shell calls within orchestration flow

### Phase 2: Reuse-path orchestration (CZH-884 Reuse/direct cut B)
1. `tryFastPresentExisting()` — pure reuse decision logic
2. `runFastPresentIfAvailable()` — reuse wrapper
3. `directPresent()` — direct present path

Dependencies on terminal layer:
- Uses: `reuseSuccessOutcome()`, `classifyDirectPresentOutcome()`, `presentResultFromReuseOutcomeState()`
- No renderer/shell calls within core logic

### Phase 3: High-level flow coordination (CZH-885 Facade contraction)
1. `runPresentation()` — top-level orchestrator (calls outcomes from Phase 1+2)
2. `refreshPresentState()` — present-state coordinator (calls Phase 1+2 outcomes)
3. `planUpdate()` — planning helper (pure logic for update mode selection)

## Non-Movable Widget Functions

These remain in widget—they require live renderer/shell/input state:
- `updateAndPresent()` — entry point, integrates all paths with input/shell
- `clearPresentationSample()` — debug sampling
- `notePresentSample()` — debug sampling
- `executePresentableUpdate()` — GPU drawing execution
- `executeIncrementalPresentableUpdate()` — GPU drawing execution
- `drawPresentationBackgroundPass()` — renderer integration
- `drawPresentationGlyphPass()` — renderer integration
- `forEachPresentationDrawSpan()` — draw plan traversal
- `beginViewportClip()` — renderer state
- `logUnavailable()` — operator reporting
- `presentDraw()` — draw result handling
- `recentInputWindowActive()` — input state check
- `tryIncrementalPresentableUpdate()` — renderer decision

## Validation Checkpoints

Before each cut phase:
- Terminal layer functions compile in isolation (no widget imports)
- Widget layer delegates to terminal without re-implementing
- Outcome paths (refresh/direct/reuse) remain pure
- No circular dependencies between layers
- Tests validate both pure computation and delegation

## Summary

- **Functions to move:** 9 orchestration helpers (2+3+3+1 by phase)
- **Functions to keep:** 13 widget-renderer integration functions
- **Terminal-owned roles after S34:** All orchestration coordination + all pure computation
- **Widget-retained roles:** Integration, drawing, input, state mutation, renderer operations
