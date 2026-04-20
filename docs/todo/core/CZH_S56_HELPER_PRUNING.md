# CZH-1098: Helper Exposure Prune

Date: 2026-04-20  
Scope: Prune non-essential helper exposure while preserving explicit test-only access where required

## Production Helper Surface Review

**Total production helpers:** 11 (across 3 categories)

### Category 1: Canonical Entries (3)
1. **refreshPresentEntry** 
   - Status: ✓ ESSENTIAL — Single entry point for widget refresh path
   - Call site: Widget refresh hook (1 call site)
   - Pruning: Cannot prune; foundational to contract

2. **reuseEligibilityEntry**
   - Status: ✓ ESSENTIAL — Single entry point for widget reuse path
   - Call site: Widget reuse dispatch (1 call site)
   - Pruning: Cannot prune; foundational to contract

3. **directPresentEntry**
   - Status: ✓ ESSENTIAL — Single entry point for widget direct path
   - Call site: Widget direct dispatch (1 call site)
   - Pruning: Cannot prune; foundational to contract

### Category 2: Eligibility Checks (2)
1. **checkReuseEligibility**
   - Purpose: Determine if reuse is candidate (generation pairing)
   - Call site: Widget reuse decision (1 call site)
   - Impact: Widget must call to determine flow path
   - Status: ✓ ESSENTIAL — Decision logic cannot be embedded in entry point
   - Pruning: Cannot prune without forcing outcome construction before decision

2. **checkDirectPresentEligibility**
   - Purpose: Determine if direct present is eligible
   - Call site: Widget direct dispatch (1 call site)
   - Impact: Widget must call to determine flow path
   - Status: ✓ ESSENTIAL — Decision logic cannot be embedded in entry point
   - Pruning: Cannot prune without forcing outcome construction before decision

### Category 3: State Computation (4)
1. **refreshPresentState**
   - Purpose: Compute present state snapshot during refresh (visibility, attachment, geometry)
   - Call site: Widget refresh hook (1 call site)
   - Impact: Widget uses snapshot for viewport clipping and draw gating
   - Status: ✓ ESSENTIAL — Computation needed for GPU-level decisions
   - Pruning: Cannot prune; widget needs per-tick state

2. **computeHostSurfaceAttachmentState**
   - Purpose: Compute full attachment conjunction (pipeline ∧ host target)
   - Call site: Widget helper (imported at line 125)
   - Impact: Attachment conjunction used in outcome construction
   - Status: ✓ ESSENTIAL — Canonical computation for conjunction
   - Pruning: Cannot prune; bridges presentation bridge to outcome

3. **computePresentationSurfaceGeometry**
   - Purpose: Compute surface geometry from view dimensions and cell metrics
   - Call site: Widget planning (1+ call sites)
   - Impact: Geometry used in viewport clipping and draw commands
   - Status: ✓ ESSENTIAL — Pure geometry computation
   - Pruning: Cannot prune; no coupling, used by widget

4. **computeTerminalPresentPlanDecision**
   - Purpose: Determine which path to execute (refresh/reuse/direct)
   - Call site: Widget planning (1+ call sites)
   - Impact: Decision logic for flow selection
   - Status: ✓ ESSENTIAL — Plan decision logic
   - Pruning: Cannot prune without embedding in widget layer

### Category 4: Orchestration (2)
1. **executeRefreshPresentFlow**
   - Purpose: Orchestrate refresh cycle execution with hooks
   - Call site: Widget refresh (1 call site)
   - Impact: High-level refresh orchestration
   - Status: ✓ ESSENTIAL — Orchestration boundary for refresh
   - Pruning: Could inline into widget, but encapsulation is better

2. **presentDraw**
   - Purpose: Draw presentation onto surface
   - Call site: Widget refresh hook (1 call site)
   - Impact: GPU drawing operation
   - Status: ✓ ESSENTIAL — Drawing operation
   - Pruning: Cannot prune; GPU operation must be called

## Test-Only Helper Surface Review

**Total test-only helpers:** 4 public + 1 shared

### Category 1: Outcome Classification (2)
1. **classifyRefreshOutcome**
   - Purpose: Test analysis of refresh outcome classification
   - Test usage: Outcome validation tests
   - Status: ✓ NEEDED — Tests understand outcome semantics
   - Pruning: Keep; explicit test-only documented purpose

2. **classifyDirectPresentOutcome**
   - Purpose: Test analysis of direct outcome classification
   - Test usage: Outcome validation tests
   - Status: ✓ NEEDED — Tests understand outcome semantics
   - Pruning: Keep; explicit test-only documented purpose

### Category 2: Outcome Invariants (2)
1. **assertReuseOutcomeConsistency**
   - Purpose: Test hardening for reuse outcome invariants
   - Test usage: Outcome validation tests
   - Status: ✓ NEEDED — Tests validate internal invariants
   - Pruning: Keep; explicit test hardening

2. **assertRefreshOutcomeConsistency**
   - Purpose: Test hardening for refresh outcome invariants
   - Test usage: Outcome validation tests
   - Status: ✓ NEEDED — Tests validate internal invariants
   - Pruning: Keep; explicit test hardening

### Category 3: Outcome Construction (1 shared)
1. **reuseSuccessOutcome**
   - Purpose: Construct reuse success outcome state
   - Usage: Called by `reuseEligibilityEntry` (production) and tests
   - Status: ✓ NEEDED — Shared outcome construction
   - Pruning: Keep; deterministic construction used by both paths

## Private Helper Surface (Internal Only)

**Total private helpers:** 3 (fold helpers)

1. **foldRefreshOutcomeToPresent** — private, called by `refreshPresentEntry` only
2. **foldReuseOutcomeToPresent** — private, called by `reuseEligibilityEntry` only
3. **foldDirectOutcomeToPresent** — private, called by `directPresentEntry` only

**Status:** ✓ Already private; no pruning needed

## Pruning Conclusion: NO CHANGES REQUIRED

### Findings
- **Production surface:** 11 helpers, all essential
  - 3 canonical entries: Foundational to contract
  - 2 eligibility checks: Required for flow decisions
  - 4 state computation: Required for GPU/widget decisions
  - 2 orchestration: Required for flow execution

- **Test-only surface:** 4 public + 1 shared, all needed
  - Classification helpers: Tests need to understand outcomes
  - Invariant helpers: Tests need to validate constraints
  - Shared construction: Deterministic outcome building

- **Private surface:** 3 fold helpers, all enforced
  - Compile-time enforcement via `fn` (not `pub fn`)
  - Inaccessible to production code

### Exposure Already Optimal
- No duplicate helpers
- No redundant routing
- No unused functions
- No test helpers called from production
- All production helpers have explicit purpose
- All test-only helpers isolated and documented

## Pruning Action: NONE

**Verdict:** Helper surface is already optimally tightened.

**Status:** ✓ COMPLETE — No changes required

**Next phase:** Lock invariants (CZH-1099)
