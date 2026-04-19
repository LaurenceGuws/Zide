# CZH-841: Consolidation follow-through audit + scope lock

Date: 2026-04-19  
Sprint: `CZH-S30`  
Batch: `CZH-B35`  
Gate target: `CZH-GATE-89`

## Executive Summary

Present/outcome seam consolidation follow-through. CZH-B34 completed hardening work; CZH-B35 consolidates patterns and reduces duplication in outcome state flows. Identified consolidation opportunities that unify helper usage, reduce duplicate branches, and strengthen canonical routes without behavior changes.

## Outcome State Consolidation Opportunities

### Opportunity A: Outcome Fold Composition Consolidation (CZH-843)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Three fold functions with similar structure but different type signatures:
1. `presentResultFromOutcomeState()` - generic fold from outcome fields
2. `presentResultFromRefreshOutcomeState()` - refresh outcome wrapper
3. `presentResultFromReuseOutcomeState()` - reuse outcome wrapper

**Consolidation Opportunity:** Create a unified fold composition pattern that reduces duplication:

```
Observation: Both refresh and reuse folds call the generic fold and add outcome-type-specific fields.
Consolidation: Factor out the pattern of "call generic fold + add outcome-type-specific field assignments"
into a helper that both path can share.

Example:
fn addOutcomeFollowup(result: *TerminalPresentResult, followup_required: bool, followup_reason: ...) void {
    result.followup.required = followup_required;
    result.followup.reason = followup_reason;
}
```

**Scope:** Helper consolidation; no behavior change, no ABI change.

**Callsites:** `presentResultFromRefreshOutcomeState()` (line 252) and `presentResultFromReuseOutcomeState()` (line 281).

---

### Opportunity B: Outcome Classification Helper Routes (CZH-844)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** 
- `classifyRefreshOutcome()` derives outcome from `TerminalPresentableRefresh` enum
- `classifyDirectPresentOutcome()` derives outcome from `updated` bool
- Both construct RefreshOutcomeState and DirectPresentOutcomeState differently

**Consolidation Opportunity:** Create a shared helper for outcome classification that reduces initialization duplication:

```
Observation: Both classification functions build outcome states by deriving multiple fields
from the same source information. Some field patterns are repeated.

Consolidation: Create `initOutcomeStateFields()` helper or similar that takes outcome + boolean flags
and returns the common fields, then outcome-specific code adds type-specific fields.
```

**Scope:** Helper consolidation; no behavior change.

**Impact:** Reduces duplication in `classifyRefreshOutcome()` and `classifyDirectPresentOutcome()`.

---

### Opportunity C: Outcome Assertion Consolidation (CZH-845)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Three separate assertion helpers for different outcome types:
1. `assertReuseOutcomeConsistency()` - validates reuse outcomes
2. `assertDirectPresentOutcomeConsistency()` - validates direct outcomes
3. Inline assertions in `classifyRefreshOutcome()` - validates refresh followup coupling

**Consolidation Opportunity:** Consolidate assertion patterns and create `assertRefreshOutcomeConsistency()` helper:

```
Observation: All three outcome types have field consistency invariants.
Consolidation: Create explicit helpers for each type with consistent naming pattern,
then use those helpers uniformly in classification and fold functions.
```

**Scope:** Helper consolidation and naming consistency; no behavior change.

---

### Opportunity D: Fold Path Selection Consolidation (CZH-846)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:** Multiple places where outcome type determines which fold path to use:
1. Line 1168: `classifyRefreshOutcome()` → `presentResultFromRefreshOutcomeState()`
2. Line 380: `tryFastPresentExisting()` → `presentResultFromReuseOutcomeState()`
3. Line 1532: `classifyDirectPresentOutcome()` → `presentResultFromOutcomeState()` (generic)

**Consolidation Opportunity:** Create unified fold dispatcher that routes outcomes to correct fold function:

```
Observation: The decision of "which fold to call" is made in three different places
based on outcome type. This logic could be unified.

Consolidation: Create a fold dispatcher that takes any outcome type and routes to
the correct fold function, centralizing the path selection logic.

Example:
fn foldOutcomeToResult(outcome: anytype, timing: ...) TerminalPresentResult {
    if (@TypeOf(outcome) == RefreshOutcomeState) {
        return presentResultFromRefreshOutcomeState(outcome, timing, ...);
    } else if (@TypeOf(outcome) == ReusePresentOutcomeState) {
        return presentResultFromReuseOutcomeState(outcome, timing);
    } else ...
}
```

**Scope:** Fold dispatcher helper; no behavior change.

**Impact:** Centralizes fold path selection, reduces conditional logic duplication.

---

## CZH-849 Hygiene Scope

Files to audit for stale probe/debug residue:
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
2. `src/ui/widgets/terminal_widget_presentation_state.zig` (if touched)
3. `src/ui/widgets/terminal_widget_surface_state.zig` (if touched)
4. `docs/todo/core/CZH_841_CONSOLIDATION_AUDIT.md` (audit document)

---

## Behavior-Freeze Guardrails (CZH-S30)

**Default assumption:** All consolidation work preserves behavior.

**Consolidation scope:** All changes are helper refactoring and pattern unification:
- No success-path changes
- No field reassignments or initialization changes
- No conditional logic modifications
- Documentation and naming consistency only

**Current status:** No behavior changes anticipated; all consolidation is defensive refactoring.

---

## Ready for CZH-842

✓ Audit complete. Four consolidation opportunities identified.  
✓ Scope locked: CZH-843 (fold composition) + CZH-844 (classification helpers) + CZH-845 (assertion consolidation) + CZH-846 (fold dispatcher).  
✓ No showstoppers. All patterns are well-established from CZH-B34 work.  
✓ Proceeding with doc tightening (CZH-842) and consolidation implementation (CZH-843..CZH-846).
