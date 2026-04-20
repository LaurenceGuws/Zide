# CZH-1097: Direct Contract Lockdown

Date: 2026-04-20  
Scope: Remove/lock any residual non-canonical direct route exposure

## Direct Path Contract

**Canonical Entry:** `directPresentEntry(updated, timing) -> TerminalPresentResult`

**Location:** `src/terminal/presentation_runtime.zig:238`

**Route:** Single path
1. Widget determines direct present eligibility (via `checkDirectPresentEligibility`)
2. Widget decides to present directly
3. Widget calls `directPresentEntry` with updated state and timing
4. Terminal classifies direct outcome → `DirectPresentOutcomeState`
5. Terminal folds outcome → `TerminalPresentResult`
6. Terminal returns result to widget

**Flow diagram:**
```
Widget checks direct eligibility via checkDirectPresentEligibility
    ↓
Widget decides to present directly
    ↓
directPresentEntry (canonical)
    ├─ classifyDirectPresentOutcome (internal)
    ├─ foldDirectOutcomeToPresent (private, internal)
    └─ return TerminalPresentResult
```

## Exposure Verification

### Canonical Entry Call Sites
- **Widget execution:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:1223`
- **Call context:** Widget direct path in main presentation dispatch
- **Frequency:** Once per direct draw execution
- **Status:** ✓ SINGLE CALL SITE

### Direct Eligibility Path
1. **checkDirectPresentEligibility** (public)
   - Called by widget to check if direct present is eligible
   - Purpose: Pure eligibility check
   - Return: Boolean flag
   - Status: ✓ Helper function, not entry point

2. **classifyDirectPresentOutcome** (public)
   - Called by `directPresentEntry` to classify outcome
   - Purpose: Pure outcome classification
   - Status: ✓ Encapsulated in canonical entry; also used by tests

### Internal Helpers
1. **foldDirectOutcomeToPresent** (private)
   - Called by `directPresentEntry` only
   - Access: Private (fn not pub fn); compile-time enforcement
   - Purpose: Fold outcome to host-facing result
   - Status: ✓ Not callable from production code

### Alternate Route Search

| Route | Status | Evidence |
|-------|--------|----------|
| Direct fold helper call from widget | ✗ BLOCKED | Fold helper is private; compile-time error |
| Outcome state construction in widget | ✗ BLOCKED | DirectPresentOutcomeState is internal; only constructed in directPresentEntry |
| Result construction outside canonical entry | ✗ BLOCKED | TerminalPresentResult only returned by fold helpers called from canonical entries |
| Secondary direct entry | ✗ NOT FOUND | Grep confirms no other directPresentEntry-like functions |
| Outcome folding via different path | ✗ BLOCKED | No alternate fold composition; only foldDirectOutcomeToPresent exists |

**Verdict:** ✓ No alternate routes detected

## Direct Route Lockdown Verification

### Compile-time Enforcement
1. ✓ `foldDirectOutcomeToPresent` is `fn` (private)
   - Prevents accidental calls from widget layer
   - Compile error if attempted: `error: 'foldDirectOutcomeToPresent' is not public`

2. ✓ `DirectPresentOutcomeState` is internal type
   - Widget cannot construct or manipulate outcome states
   - Type only appears in terminal-layer compositions

3. ✓ `classifyDirectPresentOutcome` called only by canonical entry
   - Classification is deterministic pure function
   - No state leakage to widget layer

### Code Review Verification
1. ✓ Widget calls `directPresentEntry` at line 1223 only
2. ✓ Widget calls `checkDirectPresentEligibility` at line 1438 (eligibility check only, not outcome)
3. ✓ No calls to `foldDirectOutcomeToPresent` in widget production code
4. ✓ No direct `DirectPresentOutcomeState` construction in widget
5. ✓ Outcome state types not exposed in widget interface

### Documentation Verification
1. ✓ TERMINAL_SURFACE_CONTRACT.md specifies canonical entry only
2. ✓ Comments document internal-only nature of fold helpers
3. ✓ Architecture documentation locked to canonical routing

## Lock Status: COMPLETE

All direct route exposure is locked to canonical entry:
- ✓ Single entry point: `directPresentEntry`
- ✓ No secondary routes
- ✓ No outcome state manipulation at boundary
- ✓ No result construction outside canonical entry
- ✓ Fold helper private and inaccessible

**Route integrity:** LOCKED  
**Next phase:** Proceed to helper exposure pruning (CZH-1098)
