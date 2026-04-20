# CZH-1121: Direct Path Final Seal Verification

Date: 2026-04-20  
Scope: Final verification that direct path is locked and ready for seal

## Direct Path Canonical Entry

**Entry Point:** `directPresentEntry(updated, timing)`
- Location: `src/terminal/presentation_runtime.zig:229`
- Returns: `TerminalPresentResult`
- Single canonical entry for all direct path presentation

## Direct Path Route Lock

### Outcome Classification
- **Function:** `classifyDirectPresentOutcome(updated)` (line 103)
- **Called from:** `directPresentEntry` line 232
- **Visibility:** Public (used for testing outcome classification)
- **Status:** ✓ LOCKED

### Outcome Folding
- **Function:** `foldDirectOutcomeToPresent(outcome, timing)` (line 220)
- **Visibility:** Private (fn, not pub fn)
- **Called from:** `directPresentEntry` line 233 only
- **Alternate routes:** None (private prevents bypass)
- **Status:** ✓ LOCKED

### Helper Transport
- **Function:** `directTransportFromUpdated(updated)` (line 238)
- **Purpose:** Internal transport field construction for direct outcome
- **Visibility:** Private
- **Called from:** `classifyDirectPresentOutcome` only
- **Status:** ✓ LOCKED

### Generic Fold Composition
- **Function:** `presentResultFromOutcomeState(outcome_state, timing)` (line 125)
- **Called from:** `foldDirectOutcomeToPresent` only
- **Visibility:** Private
- **Status:** ✓ LOCKED

## Direct Path Invariants (Post-Compression)

### No-Bypass Invariant
- **Rule:** Widget direct path must flow through `directPresentEntry` only
- **Enforcement:** `foldDirectOutcomeToPresent` is private
- **Verification:** No alternate fold routes exist
- **Status:** ✓ LOCKED

### Field Value Guarantees
- **Rule:** Direct path always produces fixed field values
- **Guarantees:**
  - `cache_state_advanced`: always true (direct always advances cache)
  - `host_surface_target_available`: always true (direct assumes available)
  - `shared_surface_attachment_ready`: always false (direct pre-set to false)
- **Enforcement:** `directTransportFromUpdated()` construction logic
- **Status:** ✓ VERIFIED

### Outcome Type Invariant
- **Rule:** Direct classification always produces one of two outcome types
- **Possible outcomes:** `.updated_and_presented` | `.presented`
- **Enforcement:** Deterministic classification from updated flag
- **Status:** ✓ VERIFIED

## Direct Path Widget Integration

### Widget Entry Point
- **Function:** `directPresentEntry()`
- **Called from:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:1223`
- **Frequency:** Once per direct draw attempt
- **Argument sources:** updated flag + timing
- **Status:** ✓ VERIFIED

### Widget Support Helpers
- **Eligibility check:** `checkDirectPresentEligibility()` (line 523)
- **Called from:** widget line 1438 (before canonical entry)
- **Purpose:** Determine direct draw eligibility before entering canonical entry
- **Status:** ✓ VERIFIED

## Direct Path Assertion Surface

### Contract-Critical Assertions
- **Status:** None (direct path validates via logic guarantees)
- **Rationale:** Fields are guaranteed by construction; no assertion needed

### Test Hardening Assertions
- **Status:** None (direct path field guarantees are deterministic)
- **Rationale:** No field variation possible; no test hardening needed

### Implementation Detail Assertions (Removed in CZH-S58)
- **Removed:** Lines 245-247 in `directPresentEntry`
- **Removed checks:**
  - `cache_state_advanced == true`
  - `host_surface_target_available == true`
  - `shared_surface_attachment_ready == false`
- **Removal reason:** Fields guaranteed by directTransportFromUpdated logic
- **Status:** ✓ COMPLETE

## Direct Path Compression Verification (CZH-S58)

**Pre-compression state:**
- Assertions: 1 field value validation
- Fold helpers: Private (cannot bypass)
- Entry point: Single canonical `directPresentEntry`

**Post-compression state:**
- Assertions: 0 (all implementation detail)
- Removed: Lines 245-247 field value assertions
- Compression result: 1 assertion removed (all assertions in direct path were redundant)

**Status:** ✓ OPTIMIZED (all redundant assertions removed)

## Direct Path Final Seal Checklist

- ✓ Canonical entry point established and locked (`directPresentEntry`)
- ✓ No alternate fold routes (foldDirectOutcomeToPresent is private)
- ✓ No alternate outcome classification paths
- ✓ Widget integration single-site verified (line 1223)
- ✓ Eligibility check separate from entry point (line 1438)
- ✓ No-bypass invariant enforced (compile-time privacy)
- ✓ Field value guarantees verified (construction logic)
- ✓ Outcome type invariant verified (deterministic classification)
- ✓ No test-only assertions (direct path is deterministic)
- ✓ No contract-critical assertions (all checks redundant with logic)
- ✓ All implementation assertions removed
- ✓ Full validation passed (build + tests)

**Direct path status:** ✓ READY FOR FINAL SEAL

All direct path semantics, routing, and invariants are locked. Compression completed with all implementation detail assertions removed. No further optimization possible. Ready to advance to next sprint.

Next: CZH-1122 shared surface lock
