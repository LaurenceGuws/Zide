# CZH-1096: Reuse Contract Lockdown

Date: 2026-04-20  
Scope: Remove/lock any residual non-canonical reuse route exposure

## Reuse Path Contract

**Canonical Entry:** `reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) -> TerminalPresentResult`

**Location:** `src/terminal/presentation_runtime.zig:191`

**Route:** Single path
1. Widget determines reuse eligibility (via `checkReuseEligibility`)
2. Widget calls `reuseEligibilityEntry` with eligibility decision and attachment state
3. Terminal constructs outcome based on eligibility decision
4. Terminal folds outcome → `TerminalPresentResult`
5. Terminal returns result to widget

**Flow diagram:**
```
Widget checks reuse eligibility via checkReuseEligibility
    ↓
reuseEligibilityEntry (canonical)
    ├─ reuseSuccessOutcome (internal, if eligible)
    ├─ ReusePresentOutcomeState (internal, if not eligible)
    ├─ foldReuseOutcomeToPresent (private, internal)
    └─ return TerminalPresentResult
```

## Exposure Verification

### Canonical Entry Call Sites
- **Widget execution:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:1404`
- **Call context:** Widget reuse path in main presentation dispatch
- **Frequency:** Once per reuse attempt decision
- **Status:** ✓ SINGLE CALL SITE

### Eligibility Decision Path
1. **checkReuseEligibility** (public)
   - Called by widget to determine eligibility decision
   - Purpose: Pure eligibility check (generation pairing)
   - Return: Boolean flag
   - Status: ✓ Helper function, not entry point

2. **reuseSuccessOutcome** (public)
   - Called by `reuseEligibilityEntry` when eligible
   - Purpose: Construct success outcome state
   - Status: ✓ Encapsulated in canonical entry; also used by tests

### Internal Helpers
1. **foldReuseOutcomeToPresent** (private)
   - Called by `reuseEligibilityEntry` only
   - Access: Private (fn not pub fn); compile-time enforcement
   - Purpose: Fold outcome to host-facing result
   - Status: ✓ Not callable from production code

### Alternate Route Search

| Route | Status | Evidence |
|-------|--------|----------|
| Direct fold helper call from widget | ✗ BLOCKED | Fold helper is private; compile-time error |
| Outcome state construction in widget | ✗ BLOCKED | ReusePresentOutcomeState is internal; only constructed in reuseEligibilityEntry |
| Result construction outside canonical entry | ✗ BLOCKED | TerminalPresentResult only returned by fold helpers called from canonical entries |
| Secondary reuse entry | ✗ NOT FOUND | Grep confirms no other reuseEligibilityEntry-like functions |
| Outcome folding via different path | ✗ BLOCKED | No alternate fold composition; only foldReuseOutcomeToPresent exists |
| reusePresentEntry bypass | ✓ REMOVED | Collapsed into reuseEligibilityEntry in CZH-1080 |

**Verdict:** ✓ No alternate routes detected

## Reuse Route Lockdown Verification

### Compile-time Enforcement
1. ✓ `foldReuseOutcomeToPresent` is `fn` (private)
   - Prevents accidental calls from widget layer
   - Compile error if attempted: `error: 'foldReuseOutcomeToPresent' is not public`

2. ✓ `ReusePresentOutcomeState` is internal type
   - Widget cannot construct or manipulate outcome states
   - Type only appears in terminal-layer compositions

3. ✓ `reuseSuccessOutcome` called only by canonical entry (and tests)
   - Success outcome construction is deterministic
   - No state leakage to widget layer

4. ✓ Prior removal of `reusePresentEntry`
   - Wrapper removed in CZH-1080; outcome construction consolidated
   - No secondary entry path exists

### Code Review Verification
1. ✓ Widget calls `reuseEligibilityEntry` at line 1404 only
2. ✓ Widget calls `checkReuseEligibility` at line 1370 (eligibility decision only, not outcome)
3. ✓ No calls to `foldReuseOutcomeToPresent` in widget production code
4. ✓ No direct `ReusePresentOutcomeState` construction in widget
5. ✓ Outcome state types not exposed in widget interface

### Documentation Verification
1. ✓ TERMINAL_SURFACE_CONTRACT.md specifies canonical entry only
2. ✓ Comments document internal-only nature of fold helpers
3. ✓ Prior removal of reusePresentEntry documented in CZH-1080
4. ✓ Architecture documentation locked to canonical routing

## Lock Status: COMPLETE

All reuse route exposure is locked to canonical entry:
- ✓ Single entry point: `reuseEligibilityEntry`
- ✓ No secondary routes (reusePresentEntry removed)
- ✓ No outcome state manipulation at boundary
- ✓ No result construction outside canonical entry
- ✓ Fold helper private and inaccessible

**Route integrity:** LOCKED  
**Next phase:** Proceed to direct path lockdown (CZH-1097)
