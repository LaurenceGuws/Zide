# CZH-1087..1089: Test-Surface Isolation Cuts

Date: 2026-04-20  
Status: Completed (isolation already enforced from CZH-S54)

## Refresh Test-Surface Isolation (CZH-1087)

**Requirement:** Ensure refresh production path cannot consume test-only fold helpers.

**Implementation:** `foldRefreshOutcomeToPresent` is private (fn not pub fn).

**Verification:**
- Production widget code: calls `refreshPresentEntry` only
- Test code: can access `foldRefreshOutcomeToPresent` via import in test blocks
- No secondary entry routes in production path

**Invariant:** Refresh production boundary flows through `refreshPresentEntry` only.

**Status:** ✓ ISOLATED

---

## Reuse Test-Surface Isolation (CZH-1088)

**Requirement:** Ensure reuse production path cannot consume test-only fold helpers.

**Implementation:** `foldReuseOutcomeToPresent` is private (fn not pub fn).

**Verification:**
- Production widget code: calls `reuseEligibilityEntry` only
- Test code: can access `foldReuseOutcomeToPresent` via import in test blocks
- No secondary entry routes in production path

**Invariant:** Reuse production boundary flows through `reuseEligibilityEntry` only.

**Status:** ✓ ISOLATED

---

## Direct Test-Surface Isolation (CZH-1089)

**Requirement:** Ensure direct production path cannot consume test-only fold helpers.

**Implementation:** `foldDirectOutcomeToPresent` is private (fn not pub fn).

**Verification:**
- Production widget code: calls `directPresentEntry` only
- Test code: can access `foldDirectOutcomeToPresent` via import in test blocks
- No secondary entry routes in production path

**Invariant:** Direct production boundary flows through `directPresentEntry` only.

**Status:** ✓ ISOLATED

---

## Summary

All three fold helpers are private and inaccessible to production code.
Test code can access them through imports for hardening and outcome testing.
No production paths attempt to call fold helpers directly.

**Isolation mechanism:** Zig private function declaration (fn vs pub fn)
**Test access:** Allowed via module import in test blocks
**Production access:** Compile-time error if attempted

All three surfaces isolated and locked.
