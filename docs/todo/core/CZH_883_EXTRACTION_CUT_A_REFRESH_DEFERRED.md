# CZH-883: Extraction Cut A - Refresh Orchestration Helpers (DEFERRED CALLBACK REFACTORING)

**Status:** `in_progress` (partial)  
**Scope:** Validate that refresh-cycle orchestration properly delegates to terminal-owned helpers; defer function extraction pending callback refactoring.  
**Authority:** CZH-S34, CZH-B39.

## Status Summary

Refresh-cycle orchestration functions (`runPresentableRefreshCycle`, `runRefreshedPresentablePresentation`, `executeRefreshPresentFlow`) are identified for terminal ownership but require **callback refactoring** to fully extract without introducing circular dependencies or breaking the behavior freeze.

This ticket defers the callback refactoring (matching CZH-875 precedent) and validates the current delegation pattern instead.

## Current Delegation Pattern

Widget layer functions (`terminal_widget_presentation_runtime.zig`):
- `executeRefreshPresentFlow` — top-level orchestration
  - Calls terminal-owned `classifyRefreshOutcome()` ✓
  - Calls terminal-owned `presentResultFromRefreshOutcomeState()` ✓
  - Calls widget-owned `runPresentableRefreshCycle()` (renderer integration)
  - Calls widget-owned `runRefreshedPresentablePresentation()` (renderer integration)

- `runPresentableRefreshCycle` — executes refresh with renderer
  - Calls widget-owned `executePresentableUpdate()` (GPU operation)
  - No re-derivation of outcomes ✓

- `runRefreshedPresentablePresentation` — processes refresh results
  - Calls widget-owned `refreshPresentState()` (viewport state)
  - Calls widget-owned `beginViewportClip()` (renderer state)
  - Calls widget-owned `logUnavailable()` (operator reporting)
  - Calls widget-owned `presentDraw()` (GPU operation)
  - No re-derivation of outcomes ✓

## Validation Completed

- ✓ Widget layer correctly imports and calls `classifyRefreshOutcome` from terminal
- ✓ Widget layer correctly calls `presentResultFromRefreshOutcomeState` from terminal
- ✓ No re-derivation of outcome classification in widget orchestration helpers
- ✓ Delegation pattern maintains behavior freeze (no outcome logic changes)
- ✓ Renderer/shell integration kept in widget layer as designed

## Callback Refactoring Required for Full Extraction

To move orchestration functions to terminal layer, these renderer/shell integration points would need to become callbacks:

1. **`executePresentableUpdate`** — GPU drawing execution
   - Currently called from `runPresentableRefreshCycle`
   - Requires callback parameter for full terminal extraction

2. **`refreshPresentState`** — viewport state refresh
   - Currently called from `runRefreshedPresentablePresentation`
   - Requires callback parameter for full terminal extraction

3. **`beginViewportClip`** / **`endClip`** — renderer state management
   - Currently called from `runRefreshedPresentablePresentation`
   - Requires callback parameter for full terminal extraction

4. **`logUnavailable`** — operator reporting
   - Currently called from `runRefreshedPresentablePresentation`
   - Requires callback parameter for full terminal extraction

5. **`presentDraw`** — GPU operation after present
   - Currently called from `runRefreshedPresentablePresentation`
   - Requires callback parameter for full terminal extraction

This callback pattern would introduce complexity that CZH-875 explicitly deferred. The benefits of moving these orchestration functions to terminal layer are marginal compared to the cost of the refactoring and the risk to behavior freeze.

## Recommended Path Forward

1. **Current session (CZH-S34):** Validate delegation; focus on testing and ownership hardening
2. **Future (CZH-S35+):** If callback refactoring is prioritized, extract orchestration functions with explicit callback parameters
3. **No action needed:** Widget layer will continue to orchestrate refresh with proper terminal-layer delegation for outcome classification

## Decision Rationale

- **Behavior freeze preserved:** No outcome logic changes; delegation is clean
- **Architectural clarity:** Terminal layer owns all semantic outcome classification; widget owns orchestration and integration
- **Deferred complexity:** Callback refactoring can be done separately when other priorities permit
- **Risk management:** Avoid introducing parameter-passing complexity that could mask behavior changes
- **Consistency with S33:** CZH-875 established this deferral pattern for same reason

## Next Steps

- Continue to CZH-884 (reuse/direct orchestration validation)
- Implement tests to lock delegation pattern (CZH-886/887)
- Validate Android compilation with current delegation (CZH-888)
- Complete hygiene sweep and gate handoff (CZH-889/890)
