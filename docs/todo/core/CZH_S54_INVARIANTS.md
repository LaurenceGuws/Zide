# CZH-1083: Helper/Integration Invariants Lock

Date: 2026-04-20  
Scope: Lock unified entry/eligibility semantics with hardening assertions

## Canonical Entry Invariants

### refreshPresentEntry invariant
**Input:** `TerminalPresentableRefresh`, `bool` (attachment_ready), `TerminalPresentTiming`  
**Precondition:** none  
**Postcondition (guaranteed):**
- outcome in {updated_and_presented, presented}
- cache_state_advanced correlates with refresh state (true if refreshed, false otherwise)
- host_surface_target_available correlates with refresh state (false if unsupported/target_unavailable)
- shared_surface_attachment_ready matches input parameter
- followup state locked (required ↔ reason != none)

**Invariant enforcement:** assertRefreshOutcomeConsistency() at fold boundary

### reuseEligibilityEntry invariant
**Input:** `bool` (eligible), `bool` (host_surface_target_available), `bool` (shared_surface_attachment_ready), `TerminalPresentTiming`  
**Precondition:** none  
**Postcondition (guaranteed):**
- If eligible=true:
  - outcome = .reused
  - cache_state_advanced = true
  - host_surface_target_available = true
  - shared_surface_attachment_ready = true
- If eligible=false:
  - outcome = .skipped
  - cache_state_advanced = false
  - host_surface_target_available = input parameter
  - shared_surface_attachment_ready = input parameter

**Invariant enforcement:** assertReuseOutcomeConsistency() at fold boundary

### directPresentEntry invariant
**Input:** `bool` (updated), `TerminalPresentTiming`  
**Precondition:** none  
**Postcondition (guaranteed):**
- cache_state_advanced = true (always advances for direct path)
- host_surface_target_available = true (always available for direct path)
- shared_surface_attachment_ready = false (direct does not pre-verify conjunction)
- outcome correlates with updated: updated_and_presented if true, presented if false

**Invariant enforcement:** inline assertions in directPresentEntry

## Integration Invariants

### No Secondary Entry Routes
**Rule:** Widget layer must not call fold helpers directly; only canonical entries.  
**Enforcement:** fold helpers made private (fn, not pub fn) in CZH-1079..1081  
**Verification:** grep for direct fold calls in production code

### Outcome State Isolation
**Rule:** Widget layer never constructs, accesses, or manipulates outcome-state types.  
**Scope:** RefreshOutcomeState, DirectPresentOutcomeState, ReusePresentOutcomeState  
**Enforcement:** outcome states are internal to presentation_runtime; widget receives TerminalPresentResult only  
**Verification:** grep for outcome state construction in widget code

### Eligibility Decision Ownership
**Rule:** Terminal layer owns eligibility decision logic and outcome construction; widget provides input only.  
**Boundary:** Widget calls checkReuseEligibility() for decision, then passes result to reuseEligibilityEntry()  
**Invariant:** Terminal layer constructs outcome based on decision; widget does not construct alternate outcomes  
**Enforcement:** reuseEligibilityEntry is the only reuse entry point

### Attachment State Handling
**Rule:** Attachment conjunction (shared_surface_attachment_ready) must be computed once per decision point.  
**Boundary:** Computed in computeHostSurfaceAttachmentState(), passed to entry points  
**Invariant:** Widget never re-computes or re-derives attachment state  
**Enforcement:** Widget passes computed state as input, entry points use it as-is

## Testing Coverage

### Entry Point Outcome Consistency Tests
- `test "refreshPresentEntry outcome correlates with refresh state"` — verify postcondition
- `test "reuseEligibilityEntry produces reuse success outcome when eligible"` — verify reused case
- `test "reuseEligibilityEntry produces skipped outcome with input legs when ineligible"` — verify skipped case
- `test "directPresentEntry always advances cache and has host target available"` — verify postcondition

### Boundary Assertion Tests
- `test "assertRefreshOutcomeConsistency validates followup coupling"` — verify assertion
- `test "assertReuseOutcomeConsistency validates reuse success invariants"` — verify assertion

### No Bypass Tests
- `test "fold helpers are not accessible from widget module"` — prevent direct fold calls
- `test "outcome states cannot be constructed outside presentation_runtime"` — prevent widget construction

## Related Tickets

- CZH-1079: Made foldRefreshOutcomeToPresent private
- CZH-1080: Made foldReuseOutcomeToPresent private, removed reusePresentEntry
- CZH-1081: Made foldDirectOutcomeToPresent private
- CZH-1082: Documented public API surface

## Validation

All invariants are enforced at compile-time (private functions) and runtime (assertions).
No behavior changes; all invariants document existing patterns.
