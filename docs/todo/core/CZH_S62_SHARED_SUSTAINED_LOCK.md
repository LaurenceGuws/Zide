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

See TERMINAL_SURFACE_CONTRACT.md "Enforcement Layers" matrix for layer definitions.

**Per-Path Verification:**

- **Compile-Time:** ✓ `presentResultFromOutcomeState()` private; all fold helpers private (test: "helper contraction keeps canonical")
- **Runtime:** ✓ Transport fields deterministic, immutable; no conditional logic (test: "outcome folding consistent", "fold routes consume carrier")
- **Test:** ✓ Test assertions path-specific; no shared test surface (test: "helper contraction keeps collapsed surface")
- **Code Review:** ✓ Architect approval gates for shared surface changes

## Integration Enforcement Locks

- **Test-Only Surface Leak Prevention:** Test assertions isolated; ✓ No production calls detected
- **Outcome State Mutation Prevention:** Direct flow classify → fold → result; ✓ No mutations possible
- **Widget Bypass Prevention:** Outcome types internal, fold helpers private; ✓ Compile-time prevents calls
- **No-Bypass Invariant Maintenance:** All canonical entries single-site; ✓ Code review verified
- **Attachment State Consistency:** `computeHostSurfaceAttachmentState()` is only path; ✓ Single-path enforced
- **Transport Routing Immutability:** All fields set deterministically; ✓ No conditional logic

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
