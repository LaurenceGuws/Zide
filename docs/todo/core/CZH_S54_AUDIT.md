# CZH-S54 Canonical Entry/Eligibility Audit

Date: 2026-04-20  
Audit focus: Terminal presentation runtime entry point unification

## Canonical Entry Points (public API)

Three entry points capture all presentation paths:

1. **`refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) -> TerminalPresentResult`**
   - Encapsulates: classify refresh outcome + fold to result
   - Called by: widget `executeRefreshPresentFlow`
   - Status: ✓ Correct (single path per contract)

2. **`reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) -> TerminalPresentResult`**
   - Encapsulates: construct outcome from eligibility + fold to result
   - Called by: widget `tryFastPresentExisting`
   - Status: ✓ Correct (single path per contract)

3. **`directPresentEntry(updated, timing) -> TerminalPresentResult`**
   - Encapsulates: classify direct outcome + fold to result
   - Called by: widget `executeDirectPresentFlow`
   - Status: ✓ Correct (single path per contract)

## Redundant Helper Exposure

Public helpers that should be internal only:

1. **`foldRefreshOutcomeToPresent(outcome, timing) -> TerminalPresentResult`**
   - Role: internal fold helper
   - Callers: only `refreshPresentEntry` (internal)
   - Duplication: widget should call `refreshPresentEntry`, not fold directly
   - Risk: secondary entry route if callers bypass canonical entry

2. **`foldReuseOutcomeToPresent(outcome, timing) -> TerminalPresentResult`**
   - Role: internal fold helper
   - Callers: only `reusePresentEntry` (internal) 
   - Duplication: widget should call `reuseEligibilityEntry`, not fold directly
   - Risk: secondary entry route if callers bypass canonical entry

3. **`foldDirectOutcomeToPresent(outcome, timing) -> TerminalPresentResult`**
   - Role: internal fold helper
   - Callers: only `directPresentEntry` (internal)
   - Duplication: widget should call `directPresentEntry`, not fold directly
   - Risk: secondary entry route if callers bypass canonical entry

## Fully Redundant Internal Wrapper

1. **`reusePresentEntry(outcome, timing) -> TerminalPresentResult`**
   - Role: wrapper around `foldReuseOutcomeToPresent` + assertion
   - Callers: only `reuseEligibilityEntry` (internal)
   - Code: `const result = foldReuseOutcomeToPresent(...); if (...) assert(...); return result;`
   - Status: **REMOVE** - collapse into `reuseEligibilityEntry`

## Unification Strategy (tickets CZH-1079..1082)

1. **CZH-1079 (Refresh):** Verify canonical entry is only route; internal helpers remain private
2. **CZH-1080 (Reuse):** Collapse `reusePresentEntry` → `foldReuseOutcomeToPresent` call; make fold helpers private
3. **CZH-1081 (Direct):** Verify canonical entry is only route; internal helpers remain private
4. **CZH-1082 (Pruning):** Make fold helpers private; remove `reusePresentEntry`

## Widget Callsite Summary

Current state (all correct):
- `executeRefreshPresentFlow` calls `refreshPresentEntry` ✓
- `tryFastPresentExisting` calls `reuseEligibilityEntry` ✓
- `executeDirectPresentFlow` calls `directPresentEntry` ✓

No secondary helper calls in widget layer.

## Invariant Validation Required (CZH-1083)

- `refreshPresentEntry` produces outcome in {updated_and_presented, presented}
- `reuseEligibilityEntry` routes eligible case through success outcome invariant
- `directPresentEntry` produces cache_state_advanced=true, host_surface_target_available=true, shared_surface_attachment_ready=false
