# CZH-816: Present-result fold contraction audit

Date: 2026-04-19  
Sprint: `CZH-S27`  
Batch: `CZH-B32`  
Gate target: `CZH-GATE-86`

## Scope

Audit and documentation lock for present-result fold patterns. Verify field threading in outcome states, identify unused struct patterns, and ensure conjunction propagation is correct across all fold paths (refresh, reuse, direct).

## Outcome State Structure Audit

### RefreshOutcomeState
**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:177–183`

**Pattern:** Does NOT carry conjunction; passed separately to fold.
- outcome: TerminalPresentOutcome
- cache_state_advanced: bool
- host_surface_target_available: bool (leg only)
- followup_required, followup_reason: metadata

**Usage:** Line 1452 in refresh flow: `classifyRefreshOutcome(refresh)` → conjunction passed separately to fold
**Status:** ✓ Canonical (CZH-B30, CZH-B31 verified)

---

### ReusePresentOutcomeState
**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:192–201`

**Pattern:** Carries both leg and conjunction.
- reused: bool (success flag)
- outcome: TerminalPresentOutcome
- cache_state_advanced: bool
- host_surface_target_available: bool (leg only)
- shared_surface_attachment_ready: bool (conjunction)

**Callsite:** Line 340 in `runFastPresentIfAvailable`; returns via `presentResultFromReuseOutcomeState`
**Status:** ✓ Canonical (CZH-B31 verified)

---

### DirectPresentOutcomeState
**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:185–189`

**Pattern:** Hardcoded legs to true, but conjunction **not** threaded on this struct.
```zig
pub const DirectPresentOutcomeState = struct {
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = true,
    host_surface_target_available: bool = true,
};
```

**Callsite:** Line 1452 in direct present flow: `classifyDirectPresentOutcome(direct.updated)` → fields decomposed, **conjunction hardcoded to false at fold call** (line 1458)

**Issue:** DirectPresentOutcomeState declares `host_surface_target_available = true`, but the fold call does not thread a matching conjunction value. Instead, conjunction is hardcoded to `false`.

**Analysis:**
- Direct present path (lines 1446-1459) executes draw operation
- Outcome state built via `classifyDirectPresentOutcome` (outcome + cache flag)
- Legs hardcoded as true, but conjunction field is intentionally NOT added to struct
- Conjunction passed explicitly to fold as `false`

**Rationale:** The direct present flow is within the renderer execution callback and doesn't have access to the updated surface attachment state at that point. Returning `false` for conjunction is conservative — the caller has a separate context and must verify/thread the actual conjunction status.

**Status:** Intentional pattern (by design, not a bug), but struct could be unused or refactored.

---

## Fold Function Pattern Audit

### presentResultFromOutcomeState (generic fold)
**Lines:** 209–225

Generic fold that constructs `TerminalPresentResult` from outcome fields. All three outcome paths decompose and call this function.

**Status:** ✓ Canonical consolidation point

### presentResultFromRefreshOutcomeState (refresh wrapper)
**Lines:** 227–241

Wraps generic fold for refresh path, adds followup fields from outcome state. Conjunction passed as separate parameter.

**Status:** ✓ Correct threading (conjunction computed in refresh, passed to fold)

### presentResultFromReuseOutcomeState (reuse wrapper)
**Lines:** 243–253

Wraps generic fold for reuse path, extracts conjunction from outcome state field.

**Status:** ✓ Correct threading (conjunction stored in outcome, passed to fold)

---

## Direct Present Path Threading

**Location:** Lines 1452–1459

**Current Pattern:**
```zig
const outcome_state = classifyDirectPresentOutcome(direct.updated);
return presentResultFromOutcomeState(
    outcome_state.outcome,
    outcome_state.cache_state_advanced,
    outcome_state.host_surface_target_available,
    direct.timing,
    false,  // ← Hardcoded conjunction
);
```

**Issue:** DirectPresentOutcomeState is defined to take only outcome + cache flag, with legs hardcoded to true. But the fold call hardcodes conjunction to `false` instead of threading a value from the state.

**Contraction Opportunity:** The struct definition and callsite are misaligned. Options:
1. Add `shared_surface_attachment_ready` field to DirectPresentOutcomeState (mirrors ReusePresentOutcomeState pattern)
2. Or consolidate: direct present doesn't need a struct at all, compute outcome inline
3. Or document: DirectPresentOutcomeState is a lightweight helper, conjunction is always `false` in direct flow

**Recommendation:** For CZH-816 contraction, consolidate by adding conjunction field to DirectPresentOutcomeState and threading the correct value, to match the RefreshOutcomeState / ReusePresentOutcomeState pattern.

---

## Consolidation Changes for CZH-816

### Change 1: Add conjunction field to DirectPresentOutcomeState

```zig
pub const DirectPresentOutcomeState = struct {
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = true,
    host_surface_target_available: bool = true,
    shared_surface_attachment_ready: bool = false,  // ← Add field
};
```

### Change 2: Update classifyDirectPresentOutcome to return consistent struct

No change needed — the new field will use default value `false`.

### Change 3: Update fold callsite to use field instead of hardcoded value

**Before:**
```zig
return presentResultFromOutcomeState(
    outcome_state.outcome,
    outcome_state.cache_state_advanced,
    outcome_state.host_surface_target_available,
    direct.timing,
    false,
);
```

**After:**
```zig
return presentResultFromOutcomeState(
    outcome_state.outcome,
    outcome_state.cache_state_advanced,
    outcome_state.host_surface_target_available,
    direct.timing,
    outcome_state.shared_surface_attachment_ready,
);
```

This makes the direct path follow the same fold pattern as RefreshOutcomeState and ReusePresentOutcomeState, consolidating the threading model.

---

## Summary

**No behavior changes; consolidation for clarity.**

- RefreshOutcomeState: conjunction passed separately (by design)
- ReusePresentOutcomeState: conjunction as field (consistent)
- DirectPresentOutcomeState: **to be made consistent** by adding field

**Execution:** Update struct definition and one callsite. No test changes needed; behavior is unchanged (conjunction remains `false` in direct path).

---

## Ready for CZH-817

✓ Outcome state audit complete.  
✓ Fold pattern consolidation identified.  
✓ DirectPresentOutcomeState threading to be aligned.  
✓ Proceeding with consolidation implementation and test additions (CZH-817).
