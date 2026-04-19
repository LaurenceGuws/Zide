# CZH-821: Present/outcome seam hardening audit + scope lock

Date: 2026-04-19  
Sprint: `CZH-S28`  
Batch: `CZH-B33`  
Gate target: `CZH-GATE-87`

## Executive Summary

Concrete hardening opportunities in present/outcome seam. CZH-B32 consolidated outcome structures; CZH-B33 hardens the seam by adding validation, consistency checks, and explicit invariant locks to prevent invalid state combinations and catch bugs early.

## Outcome State Hardening Opportunities

### Opportunity A: Outcome-Field Consistency Validation (CZH-823)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Outcome classification functions return raw structs without validation.

**Hardening Target:** Add validation functions that check outcome state consistency:

```
Invariant 1: outcome == .reused implies:
  - cache_state_advanced == true
  - host_surface_target_available == true
  - shared_surface_attachment_ready == true
  - followup_required == false

Invariant 2: outcome == .unavailable implies:
  - cache_state_advanced == false (no state advanced on unavailable)
  - followup_required == true (unavailability must trigger followup)

Invariant 3: outcome == .updated_and_presented implies:
  - cache_state_advanced == true (update implies advancement)

Invariant 4: followup_required == true implies:
  - followup_reason != .none (must have reason for followup)
```

**Implementation:** Create hardening helpers that validate outcome state post-construction or add inline assertions in classification functions.

**Scope:** Internal validation; no behavior change, no ABI change

---

### Opportunity B: Outcome Fold Hardening (CZH-824)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Fold functions accept outcome states without pre-validation.

**Hardening Target:** 
1. Add validation at fold entry points to assert input state is consistent
2. Add validation that fold output matches expected invariants for each outcome type
3. Tighten fold logic to reject invalid combinations early

**Example Hardening:**
```zig
fn presentResultFromOutcomeState(...) TerminalPresentResult {
    // Validate input state consistency
    if (outcome == .reused) {
        assert(cache_state_advanced == true);
        assert(host_surface_target_available == true);
        assert(shared_surface_attachment_ready == true);
    }
    
    // Construct result
    var result = .{...};
    
    // Validate output consistency
    assert(!(outcome == .reused and !result.shared_surface_attachment_ready));
    
    return result;
}
```

**Scope:** Validation only; no behavior change (debug assertions for dev/test)

---

### Opportunity C: Outcome Classification Hardening (CZH-825)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Functions:**
- `classifyRefreshOutcome()` - derives outcome from refresh state
- `classifyDirectPresentOutcome()` - derives outcome from update flag
- `reuseSuccessOutcome()` - constructs successful reuse outcome

**Hardening Target:** 
1. Add post-classification validation to `classifyRefreshOutcome()` to verify field consistency
2. Document invariant relationships in doc comments
3. Consider factoring out invariant checks into reusable helper

**Scope:** Documentation + inline assertions; no behavior change

---

### Opportunity D: Outcome Flow Hardening (CZH-826)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Outcome states flow through result paths without validation at intermediate steps.

**Hardening Target:** 
1. Add boundary checks where outcomes transition between components
2. Validate that outcomes propagate correctly through fold functions
3. Add explicit invariants at decision points (e.g., "if we got here with outcome .unavailable, we shouldn't fold")

**Example Callsites:**
- Line 372-375: `updateAndPresent` outcome flow
- Line 886-950: `runPresentableRefreshCycle` outcome classification
- Line 1070+: Outcome threading through runtime paths

**Scope:** Validation and logging; potential early-exit on invalid states

---

## CZH-829 Hygiene Scope

Files to audit for stale probe/debug residue during hardening work:
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
2. `src/ui/renderer/presentable_contract.zig` (if touched for outcome docs)
3. `src/ui/widgets/terminal_widget_presentation_state.zig` (if state validation needed)

---

## Behavior-Freeze Guardrails (CZH-S28)

**Default assumption:** All tickets preserve behavior unless explicitly marked.

**Hardening scope:** Validation and assertions are acceptable under behavior freeze because:
- They do not change the success path
- They only add early detection of invalid states
- Assertions in debug builds; no runtime cost in release

**Exception for defensive code:**
If hardening requires changing field assignments to prevent invalid states (e.g., setting a field to a consistent value when it would otherwise be inconsistent), that must be explicitly marked and justified.

**Current status:** No behavior changes anticipated; hardening is defensive validation and documentation.

---

## Ready for CZH-822

✓ Audit complete. Four hardening opportunities identified.  
✓ Scope locked: CZH-823 (outcome consistency validation) + CZH-824 (fold hardening) + CZH-825 (classification hardening) + CZH-826 (flow hardening).  
✓ No showstoppers identified. All outcomes already follow consistent patterns from CZH-B32.  
✓ Proceeding with doc tightening (CZH-822) and hardening implementation (CZH-823..CZH-826).
