# CZH-884: Extraction Cut B - Reuse/Direct Orchestration Helpers (DEFERRED CALLBACK REFACTORING)

**Status:** `in_progress` (partial)  
**Scope:** Validate that reuse/direct orchestration properly delegates to terminal-owned helpers; defer function extraction pending callback refactoring.  
**Authority:** CZH-S34, CZH-B39.

## Status Summary

Reuse/direct orchestration functions (`tryFastPresentExisting`, `runFastPresentIfAvailable`, `directPresent`) are identified for terminal ownership but require **callback refactoring** to fully extract without introducing circular dependencies or breaking the behavior freeze.

This ticket defers the callback refactoring (matching CZH-883 and CZH-875 precedent) and validates the current delegation pattern instead.

## Current Delegation Pattern

Widget layer functions (`terminal_widget_presentation_runtime.zig`):

- `runFastPresentIfAvailable` — reuse path orchestration
  - Calls widget-owned `tryFastPresentExisting()` (reuse decision logic)
  - Calls terminal-owned `presentResultFromReuseOutcomeState()` ✓
  - No outcome re-derivation ✓

- `tryFastPresentExisting` — reuse eligibility decision
  - Calls widget-owned `advancePresentationCache()` (state update)
  - Returns `ReusePresentOutcomeState` (from terminal layer) ✓
  - No outcome classification re-implementation ✓

- `directPresent` — direct present path (not yet fully analyzed)
  - Would call terminal-owned `classifyDirectPresentOutcome()` (if extracted)
  - Requires renderer integration for direct present execution
  - Similar callback refactoring required as refresh path

## Validation Completed

- ✓ Widget layer correctly imports `ReusePresentOutcomeState` from terminal
- ✓ Widget layer correctly calls `presentResultFromReuseOutcomeState()` from terminal
- ✓ No re-derivation of outcome classification in reuse helpers
- ✓ Delegation pattern maintains behavior freeze (no outcome logic changes)
- ✓ Renderer/shell integration kept in widget layer as designed

## Callback Refactoring Required for Full Extraction

To move reuse/direct orchestration functions to terminal layer:

1. **`advancePresentationCache`** — cache state management
   - Currently called from `tryFastPresentExisting`
   - Requires callback parameter for full terminal extraction

2. **Renderer integration in `directPresent`** — GPU operations
   - Direct present path has renderer dependencies
   - Requires callback parameters for terminal extraction

3. **Generation-matching logic in `tryFastPresentExisting`** — reuse eligibility
   - Currently pure logic (could be extracted as-is)
   - But called from widget orchestration that has integration dependencies

This refactoring cost is similar to CZH-883's refresh path, with marginal benefit given current architecture.

## Recommended Path Forward (Consistent with CZH-883)

1. **Current session (CZH-S34):** Validate delegation; focus on testing and ownership hardening
2. **Future (CZH-S35+):** If callback refactoring is prioritized, extract orchestration functions with explicit callback parameters
3. **No action needed:** Widget layer will continue to orchestrate reuse/direct with proper terminal-layer delegation for outcome classification

## Decision Rationale

- **Consistency with CZH-883:** Same deferral pattern for same reason
- **Behavior freeze preserved:** No outcome logic changes; delegation is clean
- **Architectural clarity:** Terminal layer owns outcome classification; widget owns orchestration and integration
- **Risk management:** Avoid introducing parameter-passing complexity
- **Alignment with CZH-875:** Established pattern for deferring callback refactoring

## Next Steps

- Implement tests to lock reuse/direct delegation pattern (CZH-886/887)
- Validate Android compilation (CZH-888)
- Complete hygiene sweep and gate handoff (CZH-889/890)
