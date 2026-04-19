# CZH-901: Seam Audit + Execution-Hook Ownership Map

**Sprint:** CZH-S36  
**Date:** 2026-04-20

## Scope

Audit callback execution-hook ambiguity between terminal and widget presentation runtime after CZH-B40. Produce explicit ownership map for all decision, folding, and side-effect hooks.

## Ownership Map

### Terminal Layer — Pure Decision / Classification / Folding

These functions must be pure (no widget-specific side effects, no state mutation):

| Function | Location | Classification | Status |
|----------|----------|----------------|--------|
| `classifyRefreshOutcome` | terminal | Pure decision | ✓ Clean |
| `classifyDirectPresentOutcome` | terminal | Pure decision | ✓ Clean |
| `reuseSuccessOutcome` | terminal | Pure outcome constructor | ✓ Clean |
| `presentResultFromOutcomeState` | terminal | Pure fold | ✓ Clean |
| `presentResultFromRefreshOutcomeState` | terminal | Pure fold | ✓ Clean |
| `presentResultFromReuseOutcomeState` | terminal | Pure fold | ✓ Clean |
| `applyOutcomeSpecificFields` | terminal | Pure fold helper | ✓ Clean |
| `assertReuseOutcomeConsistency` | terminal | Pure hardening | ✓ Clean |
| `assertDirectPresentOutcomeConsistency` | terminal | Pure hardening | ✓ Clean |
| `assertRefreshOutcomeConsistency` | terminal | Pure hardening | ✓ Clean |
| `computeHostSurfaceAttachmentState` | terminal | Pure computation | ✓ Clean |
| `computePresentationSurfaceGeometry` | terminal | Pure computation | ✓ Clean |
| `computeTerminalPresentPlanDecision` | terminal | Pure decision | ✓ Clean |
| `checkReuseEligibility` | terminal | Pure decision | ✓ Clean |
| `checkDirectPresentEligibility` | terminal | Pure decision | ✓ Clean |
| `executeRefreshPresentFlow` | terminal | Orchestration sequence | ✓ Clean (routes via Hooks) |

### Terminal Layer — Side-Effect Ambiguities

| Function | Issue | Ticket |
|----------|-------|--------|
| `refreshPresentState` | Calls `surface_state.notePresentationUpdated()` — this is widget-layer state mutation inside a terminal-layer function. The function takes `surface_state: anytype` as a parameter and writes to it. Decision logic is pure; side effect is not. | CZH-903 |
| `presentDraw` | Invokes renderer through hooks — appropriate as hook dispatch, but the hook interface is informal (not typed). | CZH-903 |

### Terminal Layer — Orchestration Hooks (Informal Interface)

`executeRefreshPresentFlow` requires a `Hooks` comptime type with:
- `runCycle(ctx) -> TerminalPresentableRefreshExecutionResult`
- `runPresentation(ctx, cycle) -> RefreshedPresentablePresentationResult`

These are documented only in a comment; no formal type constraint exists.

**Issue:** Hook interface is implicit. CZH-903 should formalize or tighten.

### Widget Layer — Execution Hooks

These are correctly widget-owned. They implement integration operations:

| Function | Classification | Status |
|----------|----------------|--------|
| `executePresentableUpdate` | GPU refresh execution | ✓ Correct owner |
| `runPresentableRefreshCycle` | Refresh cycle execution | ✓ Correct owner |
| `runRefreshedPresentablePresentation` | Presentation execution | ✓ Correct owner |
| `executeRefreshPresentFlow` | Widget facade → terminal delegate | ✓ Correct (routes to terminal) |
| `tryFastPresentExisting` | Reuse execution (delegates eligibility check) | ✓ Correct |
| `runFastPresentIfAvailable` | Reuse wrapper | ✓ Correct |
| `directPresent` | Direct GPU draw (delegates eligibility check) | ✓ Correct |
| `advancePresentationCache` | Cache state mutation | ✓ Correct owner |
| `drawPresentationBackgroundPass` | GPU background draw | ✓ Correct owner |
| `drawPresentationGlyphPass` | GPU glyph draw | ✓ Correct owner |
| `beginViewportClip` | Renderer viewport setup | ✓ Correct owner |
| `logUnavailable` | Operator reporting | ✓ Correct owner |

### Findings Summary

1. **`refreshPresentState` mutation ambiguity** (CZH-903): Contains widget-layer side effect (`notePresentationUpdated`) inside a terminal-layer function. The side effect is conditional on `presentable_refresh == .refreshed`. The function should either be split (pure state computation in terminal, mutation in widget), or the widget should call `notePresentationUpdated` directly before/after `refreshPresentState`.

2. **Informal hook interface** (CZH-903): `executeRefreshPresentFlow` hook interface documented in a comment only. Should use a typed struct or at minimum a clear doc comment with a named interface definition.

3. **`refreshPresentState` parameter surface** (CZH-903): Takes 14 parameters. Many of these are passed through from the widget. Could be simplified by pre-computing conjunction in widget and passing fewer values.

4. **No issues found with reuse/direct eligibility checks** — `checkReuseEligibility` and `checkDirectPresentEligibility` are correctly pure.

5. **No issues found with fold/classification paths** — all pure.

## Corrective Plan (CZH-903/904)

### CZH-903 target: `refreshPresentState` mutation extraction

Extract `notePresentationUpdated` side effect from `refreshPresentState`:
- Widget calls `notePresentationUpdated` directly if refresh was successful
- `refreshPresentState` becomes pure state computation only
- Reduce parameter surface to what computation actually needs

### CZH-904 target: reuse/direct hook signature review

Audit `tryFastPresentExisting` and `directPresent` parameter surfaces:
- Confirm no redundant parameters being threaded through
- Confirm `checkReuseEligibility`/`checkDirectPresentEligibility` receive minimal required input

## Verdict

CZH-B40 established the correct ownership structure. The two remaining ambiguities are both in `refreshPresentState`:
1. Side effect (mutation) inside a terminal-layer function
2. Oversized parameter surface

These are addressable without behavior change. All other seams are clean.
