# CZH-1095: Refresh Contract Lockdown

Date: 2026-04-20  
Scope: Remove/lock any residual non-canonical refresh route exposure

## Refresh Path Contract

**Canonical Entry:** `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) -> TerminalPresentResult`

**Location:** `src/terminal/presentation_runtime.zig:160`

**Route:** Single path
1. Widget calls `refreshPresentEntry` with refresh cycle result and attachment state
2. Terminal classifies refresh → `RefreshOutcomeState`
3. Terminal folds outcome → `TerminalPresentResult`
4. Terminal returns result to widget

**Flow diagram:**
```
Widget execute refresh cycle
    ↓
refreshPresentEntry (canonical)
    ├─ classifyRefreshOutcome (internal)
    ├─ foldRefreshOutcomeToPresent (private, internal)
    └─ return TerminalPresentResult
```

## Exposure Verification

### Canonical Entry Call Sites
- **Widget execution:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:908`
- **Call context:** Widget refresh hook in `executeRefreshPresentFlow`
- **Frequency:** Once per refresh cycle
- **Status:** ✓ SINGLE CALL SITE

### Internal Helpers
1. **classifyRefreshOutcome** (public)
   - Called by `refreshPresentEntry` only
   - Purpose: Pure outcome classification
   - Status: ✓ Encapsulated in canonical entry

2. **foldRefreshOutcomeToPresent** (private)
   - Called by `refreshPresentEntry` only
   - Access: Private (fn not pub fn); compile-time enforcement
   - Purpose: Fold outcome to host-facing result
   - Status: ✓ Not callable from production code

### Alternate Route Search

| Route | Status | Evidence |
|-------|--------|----------|
| Direct fold helper call from widget | ✗ BLOCKED | Fold helper is private; compile-time error |
| Outcome state construction in widget | ✗ BLOCKED | RefreshOutcomeState is internal; only constructed in refreshPresentEntry |
| Result construction outside canonical entry | ✗ BLOCKED | TerminalPresentResult only returned by fold helpers called from canonical entries |
| Secondary refresh entry | ✗ NOT FOUND | Grep confirms no other refreshPresentEntry-like functions |
| Outcome folding via different path | ✗ BLOCKED | No alternate fold composition; only foldRefreshOutcomeToPresent exists |

**Verdict:** ✓ No alternate routes detected

## Refresh Route Lockdown Verification

### Compile-time Enforcement
1. ✓ `foldRefreshOutcomeToPresent` is `fn` (private)
   - Prevents accidental calls from widget layer
   - Compile error if attempted: `error: 'foldRefreshOutcomeToPresent' is not public`

2. ✓ `RefreshOutcomeState` is internal type
   - Widget cannot construct or manipulate outcome states
   - Type only appears in terminal-layer compositions

3. ✓ `classifyRefreshOutcome` called only by canonical entry
   - Classification is deterministic pure function
   - No state leakage to widget layer

### Code Review Verification
1. ✓ Widget calls `refreshPresentEntry` at line 908 only
2. ✓ No calls to `foldRefreshOutcomeToPresent` in widget production code
3. ✓ No direct `RefreshOutcomeState` construction in widget
4. ✓ Outcome state types not exposed in widget interface

### Documentation Verification
1. ✓ TERMINAL_SURFACE_CONTRACT.md specifies canonical entry only
2. ✓ Comments document internal-only nature of fold helpers
3. ✓ Architecture documentation locked to canonical routing

## Lock Status: COMPLETE

All refresh route exposure is locked to canonical entry:
- ✓ Single entry point: `refreshPresentEntry`
- ✓ No secondary routes
- ✓ No outcome state manipulation at boundary
- ✓ No result construction outside canonical entry
- ✓ Fold helper private and inaccessible

**Route integrity:** LOCKED  
**Next phase:** Proceed to reuse path lockdown (CZH-1096)
