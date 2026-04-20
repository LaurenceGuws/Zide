# CZH-1103: Refresh Surface Lock

Date: 2026-04-20  
Scope: Ensure refresh production path has no non-canonical callable helper exposure

## Refresh Path Production-Callable Surface

**Canonical Entry:** `refreshPresentEntry`

**Supporting Helpers:**
1. `refreshPresentState` — State snapshot before draw
2. `presentDraw` — GPU drawing operation
3. `executeRefreshPresentFlow` — High-level refresh orchestration (hooks pattern)

**Flow:**
```
Widget refresh cycle
  → executeRefreshPresentFlow() [orchestration]
    → runCycle hook [widget execution]
    → runPresentation hook [widget callback]
      → refreshPresentState() [state computation]
      → presentDraw() [GPU operation]
      → refreshPresentEntry() [canonical outcome]
```

## Call Site Verification

### Primary Entry Point
- **refreshPresentEntry** at `terminal_widget_presentation_runtime.zig:908` ✓
  - Called once per refresh cycle from runPresentation hook
  - Receives cycle refresh result + state conjunction + timing
  - Returns TerminalPresentResult

### Supporting Helpers
1. **refreshPresentState** at line 865 ✓
   - Called before presentDraw for state snapshot
   - Computes visibility and attachment state
   - Returns PresentationPresentState for draw/present gating

2. **presentDraw** at lines 896, 1381 ✓
   - Called when present_state.present is true
   - Executes GPU drawing operation
   - Called from both refresh and reuse paths

3. **executeRefreshPresentFlow** at line 934 ✓
   - High-level refresh orchestration wrapper
   - Delegates to widget-provided hooks (runCycle, runPresentation)
   - Returns TerminalPresentResult directly from hook

## Non-Canonical Helper Exposure Check

### Helpers NOT Called in Refresh Path
- `checkReuseEligibility` — Reuse path only (would be incorrect in refresh)
- `checkDirectPresentEligibility` — Direct path only (would be incorrect in refresh)
- `computeTerminalPresentPlanDecision` — Plan decision only (refresh is already decided)
- `computePresentationSurfaceGeometry` — Planning only, not per-refresh

**Verdict:** ✓ No non-canonical exposure in refresh path

## Outcome Handling

**Outcome Classification:**
- Internal to `refreshPresentEntry` via `classifyRefreshOutcome()`
- Widget receives TerminalPresentResult only

**Fold Helper:**
- `foldRefreshOutcomeToPresent` is private
- Called by `refreshPresentEntry` only
- Widget cannot call directly (compile-time enforcement)

## Production Surface Lock (Refresh Path)

**Locked Surface:**
1. ✓ Canonical entry: `refreshPresentEntry` only
2. ✓ State computation: `refreshPresentState` only
3. ✓ Orchestration: `executeRefreshPresentFlow`, `presentDraw`
4. ✓ No secondary eligibility checks needed (refresh is synchronous)
5. ✓ No geometry computation needed (not performed per-refresh)
6. ✓ No plan decision needed (refresh is already the chosen path)

**Lock Status:** ✓ COMPLETE

- All refresh-path helpers verified called
- No non-canonical callable helpers exposed
- No missing essential helpers
- Outcome classification internal to canonical entry
- Fold helper private and inaccessible

## Test-Only Surface (Not Exposed in Production)

- `classifyRefreshOutcome()` — Test analysis only
- `assertRefreshOutcomeConsistency()` — Test hardening only
- `foldRefreshOutcomeToPresent()` — Private, test-accessible via import

**Status:** ✓ Isolated from production path

## Summary

Refresh path production-callable surface is locked:
- Single canonical entry: `refreshPresentEntry`
- Three supporting helpers: `refreshPresentState`, `presentDraw`, `executeRefreshPresentFlow`
- No non-canonical exposure
- No secondary route options
- Outcome classification and folding encapsulated in canonical entry
- Test-only helpers isolated

**Status:** ✓ LOCKED
