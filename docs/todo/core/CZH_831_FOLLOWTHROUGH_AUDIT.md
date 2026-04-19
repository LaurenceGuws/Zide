# CZH-831: Follow-through audit + scope lock

Date: 2026-04-19  
Sprint: `CZH-S29`  
Batch: `CZH-B34`  
Gate target: `CZH-GATE-88`

## Executive Summary

Present/outcome seam hardening follow-through. CZH-B33 established core hardening for reuse outcomes and fold paths. CZH-831 identifies remaining consolidation and validation opportunities that strengthen invariant enforcement without behavior changes.

## Outcome State Hardening Follow-Through Opportunities

### Opportunity A: DirectPresentOutcomeState Validation (CZH-833)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** `classifyDirectPresentOutcome()` (line 1302) constructs outcome state with fixed field values, relying on comment for invariant documentation.

**Hardening Target:** Add validation helper for direct present outcomes:

```
Invariant for direct present:
  - cache_state_advanced == true (direct draw implies advancement)
  - host_surface_target_available == true (drawing implies renderer available)
  - shared_surface_attachment_ready == false (direct path does not pre-verify conjunction)
  - outcome == .presented or .updated_and_presented (both are valid direct outcomes)
```

**Implementation:** Create `assertDirectPresentOutcomeConsistency()` helper similar to `assertReuseOutcomeConsistency()`.

**Callsites:** `classifyDirectPresentOutcome()` at line 1302, fold at line 1490.

**Scope:** Internal validation; no behavior change, no ABI change.

---

### Opportunity B: RefreshOutcomeState Classification Hardening (CZH-834)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** `classifyRefreshOutcome()` (line 1290) derives outcome from refresh cycle with complex conditional logic.

**Hardening Target:**
1. Add post-classification validation to assert field consistency
2. Verify followup_reason aligns with followup_required
3. Document invariant relationships in function

**Example Hardening:**
```zig
fn classifyRefreshOutcome(refresh: TerminalPresentableRefresh) RefreshOutcomeState {
    const outcome_state: RefreshOutcomeState = .{
        .outcome = if (refresh == .refreshed) .updated_and_presented else .presented,
        .cache_state_advanced = refresh == .refreshed,
        .host_surface_target_available = refresh != .unsupported and refresh != .target_unavailable,
        .followup_required = refresh == .target_unavailable,
        .followup_reason = if (refresh == .target_unavailable) .target_unavailable else .none,
    };
    
    // Harden: validate followup consistency
    if (outcome_state.followup_required) {
        std.debug.assert(outcome_state.followup_reason != .none);
    } else {
        std.debug.assert(outcome_state.followup_reason == .none);
    }
    
    return outcome_state;
}
```

**Scope:** Validation only; no behavior change.

---

### Opportunity C: Surface Attachment Predicate Sync (CZH-835)

**File:** `src/ui/widgets/terminal_widget_surface_state.zig`

**Current State (post-CZH-825):** Two canonical paths for conjunction:
- **Compute+store:** `notePresentableAvailability()` (line 236) — writes leg, returns conjunction
- **Read-only derive:** `readSharedSurfaceAttachmentReady()` (line 250) — derives from stored legs

**Hardening Target:** Strengthen invariant documentation that both paths are kept in sync:

1. Add assertions in `notePresentableAvailability()` that legs are valid post-write
2. Add assertion in `readSharedSurfaceAttachmentReady()` that legs are consistent before deriving
3. Document that these two functions form a sync pair (compute vs read)

**Example Hardening:**
```zig
pub fn notePresentableAvailability(self: *TerminalWidgetSurfaceState, available: bool) bool {
    if (!available) self.presentation.invalidatePresentationCache(.{ .availability = true });
    self.presentation.host_surface_target_available = available;
    
    // Harden: legs should be initialized before returning conjunction
    std.debug.assert(self.presentation.terminal_presentable_pipeline_ready != undefined);
    std.debug.assert(self.presentation.host_surface_target_available != undefined);
    
    return surface_attachment_contract.hostSharedSurfaceAttachmentReady(
        self.presentation.terminal_presentable_pipeline_ready,
        self.presentation.host_surface_target_available,
    );
}
```

**Scope:** Debug assertions; no behavior change, no ABI change.

---

### Opportunity D: Outcome Fold Integration Strengthening (CZH-836)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Fold Paths:**
1. `presentResultFromRefreshOutcomeState()` (line 237) — refresh outcome → result
2. `presentResultFromReuseOutcomeState()` (line 258) — reuse outcome → result
3. `presentResultFromOutcomeState()` (line 213) — generic outcome → result

**Hardening Target:** Strengthen integration-level invariants:

1. Verify that fold composition preserves outcome semantics across all paths
2. Add assertion that direct outcomes (from line 1302) compose correctly through generic fold
3. Ensure followup fields propagate correctly through refresh path fold

**Example Hardening:** In `presentResultFromRefreshOutcomeState()`, after fold, assert:
```zig
// Verify followup propagates correctly
if (outcome_state.followup_required) {
    std.debug.assert(result.followup.required == true);
    std.debug.assert(result.followup.reason != .none);
}
```

**Scope:** Validation; no behavior change.

---

## CZH-839 Hygiene Scope

Files to audit for stale probe/debug residue:
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
2. `src/ui/widgets/terminal_widget_surface_state.zig` (if touched for sync pair hardening)
3. `docs/todo/core/CZH_831_FOLLOWTHROUGH_AUDIT.md` (audit document)
4. `docs/todo/core/CZH_833_RUNTIME_FOLLOWTHROUGH_AUDIT.md` (if created)
5. `docs/todo/core/CZH_835_SURFACE_SYNC_AUDIT.md` (if created)

---

## Behavior-Freeze Guardrails (CZH-S29)

**Default assumption:** All tickets preserve behavior unless explicitly marked.

**Hardening scope:** All follow-through work is validation and assertions only:
- No success-path changes
- No field reassignments
- Debug assertions only; no runtime cost in release builds
- Documentation enhancements clarify existing invariants

**Current status:** No behavior changes anticipated; all hardening is defensive validation.

---

## Ready for CZH-832

✓ Audit complete. Four follow-through opportunities identified.  
✓ Scope locked: CZH-833 (direct present hardening) + CZH-834 (refresh classification hardening) + CZH-835 (surface sync hardening) + CZH-836 (fold integration strengthening).  
✓ No showstoppers. All outcomes follow well-established patterns from CZH-B33.  
✓ Proceeding with doc tightening (CZH-832) and follow-through implementation (CZH-833..CZH-836).
