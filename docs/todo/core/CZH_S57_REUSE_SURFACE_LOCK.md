# CZH-1104: Reuse Surface Lock

Date: 2026-04-20  
Scope: Ensure reuse production path has no non-canonical callable helper exposure

## Reuse Path Production-Callable Surface

**Decision Helper:** `checkReuseEligibility`

**Canonical Entry:** `reuseEligibilityEntry`

**Supporting Helpers:**
1. `presentDraw` — GPU drawing operation (if reused)
2. No state computation helpers required (eligibility check is sufficient)

**Flow:**
```
Widget presentation planning
  → computeTerminalPresentPlanDecision() [plan logic]
    → checkReuseEligibility() [reuse decision input]
  [Widget decides to attempt reuse]
  → reuseEligibilityEntry() [canonical outcome]
  [If reused:]
  → presentDraw() [GPU operation]
```

## Call Site Verification

### Decision Helper
- **checkReuseEligibility** at `terminal_widget_presentation_runtime.zig:1370` ✓
  - Called before deciding to enter reuse path
  - Returns bool to inform flow decision
  - Input: ReuseEligibilityInput (generation pairing)

### Primary Entry Point
- **reuseEligibilityEntry** at line 1404 ✓
  - Called once per reuse attempt decision
  - Receives eligibility bool + attachment state + timing
  - Returns TerminalPresentResult (reused, skipped, or other outcome)

### Supporting Helpers
1. **presentDraw** at line 1381 ✓
   - Called if reuse outcome allows (presentable result)
   - Executes GPU drawing operation
   - Called from both refresh and reuse paths

## Non-Canonical Helper Exposure Check

### Helpers NOT Called in Reuse Path
- `checkDirectPresentEligibility` — Direct path only (would be incorrect in reuse)
- `refreshPresentState` — Refresh path only (not needed for reuse decision)
- `executeRefreshPresentFlow` — Refresh orchestration only
- `computePresentationSurfaceGeometry` — Planning only, not per-reuse
- `computeTerminalPresentPlanDecision` — Called for planning, not directly in reuse execution

**Verdict:** ✓ No non-canonical exposure in reuse path

## Outcome Handling

**Outcome Construction:**
- Internal to `reuseEligibilityEntry` via:
  - `reuseSuccessOutcome()` — if eligible
  - Outcome state literal — if not eligible
- Widget receives TerminalPresentResult only

**Fold Helper:**
- `foldReuseOutcomeToPresent` is private
- Called by `reuseEligibilityEntry` only
- Widget cannot call directly (compile-time enforcement)

## Production Surface Lock (Reuse Path)

**Locked Surface:**
1. ✓ Decision helper: `checkReuseEligibility` (must be called before entry)
2. ✓ Canonical entry: `reuseEligibilityEntry` only
3. ✓ Orchestration: `presentDraw` (if outcome allows)
4. ✓ No state computation needed (eligibility check provides decision input)
5. ✓ No direct eligibility check needed (this is the reuse path)
6. ✓ No refresh orchestration needed (this is reuse, not refresh)

**Lock Status:** ✓ COMPLETE

- All reuse-path helpers verified called
- No non-canonical callable helpers exposed
- No missing essential helpers
- Outcome construction internal to canonical entry
- Fold helper private and inaccessible

## Test-Only Surface (Not Exposed in Production)

- `classifyReusePresentOutcome()` — Test analysis (if exists)
- `assertReuseOutcomeConsistency()` — Test hardening only
- `foldReuseOutcomeToPresent()` — Private, test-accessible via import

**Status:** ✓ Isolated from production path

## Summary

Reuse path production-callable surface is locked:
- Decision helper: `checkReuseEligibility` (required before entry)
- Single canonical entry: `reuseEligibilityEntry`
- One supporting helper: `presentDraw` (conditional on outcome)
- No non-canonical exposure
- No secondary route options
- Outcome construction and folding encapsulated in canonical entry
- Test-only helpers isolated

**Status:** ✓ LOCKED
