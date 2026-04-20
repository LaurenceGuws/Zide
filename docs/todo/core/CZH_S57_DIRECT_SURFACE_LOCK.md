# CZH-1105: Direct Surface Lock

Date: 2026-04-20  
Scope: Ensure direct production path has no non-canonical callable helper exposure

## Direct Path Production-Callable Surface

**Decision Helper:** `checkDirectPresentEligibility`

**Canonical Entry:** `directPresentEntry`

**Supporting Helpers:**
1. `presentDraw` — GPU drawing operation
2. No state computation helpers required (updated flag is sufficient)

**Flow:**
```
Widget presentation planning
  → computeTerminalPresentPlanDecision() [plan logic]
    → checkDirectPresentEligibility() [direct decision input]
  [Widget decides to present directly]
  → directPresentEntry() [canonical outcome]
  → presentDraw() [GPU drawing]
```

## Call Site Verification

### Decision Helper
- **checkDirectPresentEligibility** at `terminal_widget_presentation_runtime.zig:1438` ✓
  - Called to check if direct present is eligible
  - Returns bool to inform flow decision
  - Input: DirectPresentEligibilityInput (updated state, caching info)

### Primary Entry Point
- **directPresentEntry** at line 1223 ✓
  - Called once per direct draw execution
  - Receives updated flag + timing
  - Returns TerminalPresentResult

### Supporting Helpers
1. **presentDraw** at multiple sites ✓
   - Called after directPresentEntry to execute GPU drawing
   - Executes GPU drawing operation

## Non-Canonical Helper Exposure Check

### Helpers NOT Called in Direct Path
- `checkReuseEligibility` — Reuse path only (would be incorrect in direct)
- `refreshPresentState` — Refresh path only (not needed for direct)
- `executeRefreshPresentFlow` — Refresh orchestration only
- `computePresentationSurfaceGeometry` — Planning only, not per-direct
- `computeTerminalPresentPlanDecision` — Called for planning, not directly in direct execution

**Verdict:** ✓ No non-canonical exposure in direct path

## Outcome Handling

**Outcome Classification:**
- Internal to `directPresentEntry` via `classifyDirectPresentOutcome()`
- Widget receives TerminalPresentResult only

**Fold Helper:**
- `foldDirectOutcomeToPresent` is private
- Called by `directPresentEntry` only
- Widget cannot call directly (compile-time enforcement)

## Production Surface Lock (Direct Path)

**Locked Surface:**
1. ✓ Decision helper: `checkDirectPresentEligibility` (must be called before entry)
2. ✓ Canonical entry: `directPresentEntry` only
3. ✓ Orchestration: `presentDraw` (GPU drawing operation)
4. ✓ No state computation needed (updated flag provides decision input)
5. ✓ No reuse eligibility check needed (this is direct, not reuse)
6. ✓ No refresh orchestration needed (this is direct, not refresh)

**Lock Status:** ✓ COMPLETE

- All direct-path helpers verified called
- No non-canonical callable helpers exposed
- No missing essential helpers
- Outcome classification internal to canonical entry
- Fold helper private and inaccessible

## Test-Only Surface (Not Exposed in Production)

- `classifyDirectPresentOutcome()` — Test analysis only
- `foldDirectOutcomeToPresent()` — Private, test-accessible via import

**Status:** ✓ Isolated from production path

## Summary

Direct path production-callable surface is locked:
- Decision helper: `checkDirectPresentEligibility` (required before entry)
- Single canonical entry: `directPresentEntry`
- One supporting helper: `presentDraw` (GPU operation)
- No non-canonical exposure
- No secondary route options
- Outcome classification and folding encapsulated in canonical entry
- Test-only helpers isolated

**Status:** ✓ LOCKED
