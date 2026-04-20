# CZH-1069 Outcome-State Usage Audit + Contraction Map

**Ticket:** `CZH-1069`  
**Sprint:** `CZH-S53`  
**Batch:** `CZH-B58`  
**Gate:** `CZH-GATE-112`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + contraction map only (no runtime behavior/ABI change)

## Purpose

Audit remaining production handling of outcome-state types across widget/runtime boundary,
enumerate alias/re-export/helper surfaces, and define contraction routes for `CZH-1070`..`CZH-1076`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited outcome-state usage

### Widget layer const imports (lines 123-125)

```zig
const RefreshOutcomeState = terminal_presentation_runtime.RefreshOutcomeState;
const DirectPresentOutcomeState = terminal_presentation_runtime.DirectPresentOutcomeState;
const ReusePresentOutcomeState = terminal_presentation_runtime.ReusePresentOutcomeState;
```

These are internal re-imports made private in CZH-1066. Currently used only in widget-layer tests.

### Production outcome state construction sites

**Reuse path (line 1391 onwards):**
- Location: `terminal_widget_presentation_runtime.zig:1391-1432`
- Pattern: `var outcome: ReusePresentOutcomeState = undefined;` followed by conditional construction
  - Success: `outcome = reuseSuccessOutcome();`
  - Non-reused: manual `ReusePresentOutcomeState` construction with transport fields
- Passes to: `terminal_presentation_runtime.reusePresentEntry(outcome, .{})`
- Context: `tryFastPresentExisting()` method, driven by reuse eligibility decision

**No other production outcome construction:**
- Refresh path (CZH-1063): Uses `refreshPresentEntry(refresh, attachment_ready, timing)` directly
- Direct path (CZH-1065): Uses `directPresentEntry(updated, timing)` directly
- Only reuse path still constructs outcome state in production

### Test outcome state construction sites

Lines 2034, 2045, 2058, 2070, 2081, 2092, 2117, 2193, 2200, 2215 and others: All test code.
- Construct outcome states directly for granular invariant testing
- Use const imports (lines 123-125) to access types
- Not part of production path

## Contraction target routes

**Reuse path consolidation (CZH-1072):**
- Widget should NOT construct ReusePresentOutcomeState
- Terminal layer should own outcome construction from eligibility inputs
- New function: `reuseEligibleEntry(...)` or variant for success case
- Widget calls terminal-owned function; passes eligibility/state inputs only
- Terminal returns TerminalPresentResult directly

**Alias/re-export removal (CZH-1074):**
- Remove const imports of outcome-state types (lines 123-125)
- Keep types available for tests via terminal_presentation_runtime direct access
- Reduces widget module's surface area; outcome states remain internal to terminal

**Test impact:**
- Test code references outcome-state types by full path: `terminal_presentation_runtime.RefreshOutcomeState`
- No const alias layer needed; tests still access types for granular testing
- Removes public re-export but not runtime/test functionality

## Execution cut map (`CZH-1070`..`CZH-1076`)

1. `CZH-1070` — Authority tightening (doc-only).
2. `CZH-1071` — Refresh boundary contraction (already contracted in CZH-B57; verification).
3. `CZH-1072` — Reuse boundary contraction (CZH-B57 canonical entry; widget outcome construction removal).
4. `CZH-1073` — Direct boundary contraction (already contracted in CZH-B57; verification).
5. `CZH-1074` — Internal helper surface pruning.
6. `CZH-1075` — Helper/integration invariants lock.
7. `CZH-1076` — Hygiene sweep + validation packet + gate handoff.

## Status by path

**Refresh path:** Already contracted in CZH-1063 (refreshPresentEntry canonical entry)
- Production: uses refreshPresentEntry(refresh, attachment_ready, timing) → TerminalPresentResult
- No RefreshOutcomeState construction in production
- CZH-1071 verifies boundary is clean

**Direct path:** Already contracted in CZH-1065 (directPresentEntry canonical entry)
- Production: uses directPresentEntry(updated, timing) → TerminalPresentResult
- No DirectPresentOutcomeState construction in production
- CZH-1073 verifies boundary is clean

**Reuse path:** Fully contracted in CZH-1072 (reuseEligibilityEntry new entry)
- Widget checks eligibility and executes, then calls reuseEligibilityEntry
- Terminal constructs ReusePresentOutcomeState based on eligible flag
- No outcome state construction in production widget code
- CZH-1072 moved outcome construction to terminal layer

## Contraction completion

All three presentation paths are now result-only at widget/runtime boundary:
- Refresh: refreshPresentEntry (CZH-1063 + CZH-1071 verification)
- Reuse: reuseEligibilityEntry (CZH-1072)
- Direct: directPresentEntry (CZH-1065 + CZH-1073 verification)

Widget layer never constructs outcome-state types in production; only receives TerminalPresentResult.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/timing changes.
- No FFI export/symbol changes.
- No behavioral changes to result composition.

## Audit conclusion

Widget layer currently constructs ReusePresentOutcomeState in production reuse path;
other paths (refresh/direct) already use canonical entries. Contraction goal: move
reuse outcome construction into terminal layer, making widget purely result-consuming.
All outcome-state types become internal to terminal; widget boundary is result-only.
