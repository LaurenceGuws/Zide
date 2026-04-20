# CZH-1146: Shared Transport and Integration Sustained Lock

Date: 2026-04-20  
Scope: Consolidated governance + enforcement + integration for all shared helpers and contract points

## Shared Helper Surface (Locked by CZH-S59)

### Generic Fold Composition (Locked)
- **Function:** `presentResultFromOutcomeState(outcome_state, timing) → TerminalPresentResult` (line 125)
- **Privacy:** Private (`fn`, not `pub fn`)
- **Called from:** All three fold helpers only (refresh/reuse/direct)
- **Governance:** No direct calls from widget allowed; no public exposure

### Shared Outcome Construction (Locked)
- **Function:** `reuseSuccessOutcome()` (line 112)
- **Status:** Production essential, public (called by `reuseEligibilityEntry` + tests)
- **Governance:** No alternate success outcome construction allowed

### Shared State Computation (4 functions, all locked)
1. `refreshPresentState(...)` (line 409) — production essential
2. `computeHostSurfaceAttachmentState(...)` (line 269) — production essential
3. `computePresentationSurfaceGeometry(...)` (line 299) — production essential
4. `computeTerminalPresentPlanDecision(...)` (line 342) — production essential

**Governance:** All 4 verified essential; no new shared state computation without architect approval

## Shared Governance Locks

### Lock 1: Generic Fold Composition Privacy
**Rule:** `presentResultFromOutcomeState` must remain private; widget cannot call directly.

**Guard:** Private `fn` declaration prevents compilation of direct calls
**Verification:**
- `presentResultFromOutcomeState` is private (fn not pub fn)
- Only fold helpers call this function
- No widget code references generic fold composition
**Status:** ✓ LOCKED

### Lock 2: Attachment State Single-Path Computation
**Rule:** Attachment state computed only through `computeHostSurfaceAttachmentState` + canonical bridge path.

**Guard:** Widget cannot re-derive attachment state; must use canonical computation
**Verification:**
- `computeHostSurfaceAttachmentState` is only production attachment computation
- Calls `TerminalPresentationBridge` for canonical conjunction
- No widget code re-derives attachment state independently
**Status:** ✓ LOCKED

### Lock 3: Transport Routing Immutability
**Rule:** All transport fields route through canonical fold paths; no alternate transport routing allowed.

**Guard:** Private fold helpers enforce single routing path
**Verification:**
- `refreshTransportFromResult` (private) — refresh path only
- `reuseTransportFromOutcome` (private) — reuse path only
- `directTransportFromUpdated` (private) — direct path only
- No alternate transport construction functions exist
**Status:** ✓ LOCKED

### Lock 4: No Shared Outcome Production
**Rule:** Only canonical entries produce outcomes; no shared outcome production helpers (except `reuseSuccessOutcome` which is per-path).

**Guard:** No shared outcome construction (only path-specific helpers)
**Verification:**
- `classifyRefreshOutcome` — refresh only
- `classifyDirectPresentOutcome` — direct only
- `reuseSuccessOutcome` — reuse only
- No generic outcome construction helper exists
**Status:** ✓ LOCKED

### Lock 5: State Computation Immutability
**Rule:** The 4 shared state computation functions remain essential and cannot be removed or duplicated.

**Guard:** All 4 functions verified called from production widget code
**Verification:**
- `refreshPresentState` — called from widget refresh hooks
- `computeHostSurfaceAttachmentState` — called from widget attachment state
- `computePresentationSurfaceGeometry` — called from widget geometry logic
- `computeTerminalPresentPlanDecision` — called from widget dispatch logic
**Status:** ✓ LOCKED

### Lock 6: No Shared Test-Only Surface
**Rule:** All test-only helpers are path-specific; no shared test-only surface exists.

**Guard:** Test assertions isolated per path (refresh/reuse/direct)
**Verification:**
- `assertRefreshOutcomeConsistency` (line 259) — refresh test hardening only
- `assertReuseOutcomeConsistency` (line 249) — reuse test hardening only
- No shared test hardening assertions
- No production calls to test helpers
**Status:** ✓ LOCKED

### Lock 7: Result Type Consistency
**Rule:** All canonical entries return `TerminalPresentResult`; no alternate result types.

**Guard:** Unified result type enforced across all paths
**Verification:**
- `refreshPresentEntry` → TerminalPresentResult
- `reuseEligibilityEntry` → TerminalPresentResult
- `directPresentEntry` → TerminalPresentResult
- No path-specific result types
**Status:** ✓ LOCKED

## Shared Enforcement Layers (CZH-S61 Verified)

### 1. Compile-Time Enforcement (Type System)
- **Owner:** Zig type system + module visibility
- **Responsibility:** Prevent invalid function calls at compile time
- **Enforcement:** Private fold helpers and generic composition prevent widget from calling
- **Verification:** ✓ `presentResultFromOutcomeState()` private; all fold helpers private
- **Status:** ✓ LOCKED

### 2. Runtime Enforcement (Field Guarantees)
- **Owner:** Fold helper implementation
- **Responsibility:** Ensure transport fields deterministic and immutable
- **Enforcement:** All fields set deterministically; no post-production mutations
- **Verification:** ✓ Transport fields immutable; no conditional logic
- **Status:** ✓ LOCKED

### 3. Test Enforcement (Test Coverage)
- **Owner:** Unit test suite (zig build test)
- **Responsibility:** Detect shared helper regressions and test surface isolation
- **Enforcement:** Tests verify path-specific isolation, no shared test surface
- **Verification:** ✓ Test assertions path-specific; no production calls to test surface
- **Status:** ✓ LOCKED

### 4. Code Review Enforcement (Architecture)
- **Owner:** Architect approval for shared changes
- **Responsibility:** Block new shared helpers, result type changes, composition changes
- **Enforcement:** All changes to shared surface require architect approval
- **Verification:** ✓ Result type unified across all paths; transport immutable
- **Status:** ✓ LOCKED

## Integration Enforcement Locks

### Integration Lock 1: Test-Only Surface Leak Prevention
- **Risk:** Production code imports or calls test assertions
- **Guard:** Test assertions isolated; code review enforces isolation
- **Verification:** ✓ No production calls to test helpers detected
- **Status:** ✓ LOCKED

### Integration Lock 2: Outcome State Mutation Prevention
- **Risk:** Outcome state modified after classification or between fold steps
- **Guard:** Private fold helpers enforce direct flow; type system prevents mutations
- **Verification:** ✓ Outcome flows directly: classify → fold → result
- **Status:** ✓ LOCKED

### Integration Lock 3: Widget Bypass Prevention
- **Risk:** Widget constructs outcomes or calls fold helpers directly
- **Guard:** Outcome types internal; fold helpers private
- **Verification:** ✓ Compile-time prevents outcome construction; fold helpers not callable
- **Status:** ✓ LOCKED

### Integration Lock 4: No-Bypass Invariant Maintenance
- **Risk:** Widget finds alternate path to bypass canonical entries
- **Guard:** All canonical entries called from verified sites; private fold helpers lock routes
- **Verification:** ✓ Code review verified single-site calls per path
- **Status:** ✓ LOCKED

### Integration Lock 5: Attachment State Consistency
- **Risk:** Widget re-derives attachment state instead of using canonical path
- **Guard:** `computeHostSurfaceAttachmentState()` is only attachment computation
- **Verification:** ✓ Single-path computation enforced; code review verified
- **Status:** ✓ LOCKED

### Integration Lock 6: Transport Routing Immutability
- **Risk:** Transport fields made conditional or modified post-production
- **Guard:** Private fold helpers with deterministic field logic
- **Verification:** ✓ All transport fields set deterministically; no conditional logic
- **Status:** ✓ LOCKED

## Shared Change Control

**What requires architect approval:**
- Changes to generic fold composition (affects all paths)
- New shared state computation functions
- Changes to result type set (TerminalPresentResult fields)
- New shared test helpers
- Changes to attachment computation semantics
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal state computation (output unchanged)
- Test-only assertions in path-specific helpers
- Comments and documentation

## Integration Points Governance

### Widget-to-Terminal Seam (Locked)
- Widget calls only 3 canonical entries + 6 support helpers
- No fold helper calls from widget possible (private)
- No outcome state construction from widget possible (internal types)
- **Enforcement:** Compile-time + code review ✓ LOCKED

### Terminal-Internal Seam (Locked)
- Public classification/construction → canonical entries → private fold → generic composition
- All paths converge at single result type
- No bypasses possible (private fold helpers)
- **Enforcement:** Type system + privacy enforcement ✓ LOCKED

## Sustained Lock Checklist

- ✓ Generic fold composition private (no widget access possible)
- ✓ Outcome construction path-specific (no shared outcome helpers)
- ✓ Transport routing locked (private fold helpers enforce paths)
- ✓ Attachment state single-path (canonical computation enforced)
- ✓ State computation essential (all 4 verified called from production)
- ✓ Test surface isolated (no shared test helpers)
- ✓ Result type unified (all paths return TerminalPresentResult)
- ✓ No alternate routing (all paths through canonical entries)
- ✓ Test-only surface leak prevented (code review verified)
- ✓ Outcome state mutation prevented (direct flow enforced)
- ✓ Widget bypass prevented (type system enforced)
- ✓ No-bypass invariant maintained (call sites verified)
- ✓ Attachment consistency maintained (single-path verified)
- ✓ Transport routing immutable (deterministic field logic)
- ✓ Compile-time enforcement (type system)
- ✓ Runtime enforcement (field guarantees)
- ✓ Test enforcement (coverage)
- ✓ Code review enforcement (architecture gates)

**Shared transport and integration sustained lock:** ✓ COMPLETE AND LOCKED

All 5 regression vectors + 4 extension vectors protected by enforcement stack.

Status: Ready for integration with CZH-1147 regression/integration verification
