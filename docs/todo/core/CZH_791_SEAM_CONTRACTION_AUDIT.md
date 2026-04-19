# CZH-791: Seam-contraction audit + hygiene scope

Date: 2026-04-19  
Sprint: CZH-S25  
Batch: CZH-B30  
Gate target: CZH-GATE-84

## Executive Summary

Map duplicate conjunction/leg derivation callsites across selected runtime/widget seams and identify canonical helper route per flow. Two canonical routes for conjunction derivation exist: compute-on-demand via `surface_attachment_contract.hostSharedSurfaceAttachmentReady()` or read-stored via `TerminalWidgetSurfaceState.readSharedSurfaceAttachmentReady()`. Parallel derivation found in outcome folding path where conjunction is lost.

## Canonical Helper Routes (Frozen)

### Route 1: Direct Conjunction Compute (Pure Function)
**Location:** `src/terminal/surface_attachment_contract.zig:39–44`

```zig
pub fn hostSharedSurfaceAttachmentReady(
    terminal_presentable_pipeline_ready: bool,
    host_surface_target_available: bool,
) bool {
    return terminal_presentable_pipeline_ready and host_surface_target_available;
}
```

**Wrapper:** `hostSharedSurfaceAttachmentReadyFromPair(pair)` (line 52–57)  
**Tests:** Lines 59–86 lock AND semantics  
**Authority:** `CZH-S15`, `CZH-S18`

---

### Route 2a: Widget Conjunction Compute + Store (Imperative)
**Location:** `src/ui/widgets/terminal_widget_surface_state.zig:230–237`

```zig
pub fn notePresentableAvailability(self: *TerminalWidgetSurfaceState, available: bool) bool {
    if (!available) self.presentation.invalidatePresentationCache(.{ .availability = true });
    self.presentation.host_surface_target_available = available;  // Write leg
    return surface_attachment_contract.hostSharedSurfaceAttachmentReady(
        self.presentation.terminal_presentable_pipeline_ready,
        self.presentation.host_surface_target_available,
    );
}
```

**Phases:**
1. **Compute** via canonical helper (line 233–236)
2. **Store** host leg on `PresentationState` (line 232)
3. **Return** conjunction from computed state
4. **Invalidate** presentation cache on unavailability

**Authority:** `CZH-S22` (compute phase), `CZH-S15` (seam naming)  
**Tests:** `CZH-S15` + `CZH-767` contracts (lines 298–329)

---

### Route 2b: Widget Conjunction Read (Read-Only)
**Location:** `src/ui/widgets/terminal_widget_surface_state.zig:243–248`

```zig
pub fn readSharedSurfaceAttachmentReady(self: *const TerminalWidgetSurfaceState) bool {
    return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = self.presentation.terminal_presentable_pipeline_ready,
        .host_surface_target_available = self.presentation.host_surface_target_available,
    });
}
```

**Property:** Read-only; must match stored legs from prior `notePresentableAvailability` call  
**Authority:** `CZH-S23` (reporting-carrier), `CZH-S24` (cohesion)  
**Tests:** `CZH-S15` contract validation (line 298–308)

---

### Route 3: Transient Present-State Conjunction Store
**Location:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:115–124`

```zig
pub const PresentationPresentState = struct {
    updated: bool = false,
    presentable_refresh: TerminalPresentableRefresh = .unsupported,
    host_surface_target_available: bool = false,
    /// Full shared-surface attachment for this tick (`notePresentableAvailability`); not the host-target leg alone.
    shared_surface_attachment_ready: bool = false,
    visible: bool = false,
    present: bool = false,
    log_unavailable: bool = false,
};
```

**Phases:**
1. **Compute** via `notePresentableAvailability` (line 1571 in `refreshPresentState`)
2. **Store** snapshot on `PresentationPresentState` (line 1572)
3. **Report** via `logUnavailable()` using stored field only (line 1600)

**Invariant:** Only `logUnavailable()` reads `shared_surface_attachment_ready` from this struct; other paths must not alias this field.  
**Authority:** `CZH-S22` (conjunction propagation), `CZH-S23` (reporting-carrier), `CZH-B24` (observability)  
**Tests:** Implicit in `refreshPresentState` + `logUnavailable` contract

---

### Route 4: Runtime Outcome Conjunction (Partial Propagation Bug)
**Location:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:183–191`

```zig
pub const ReusePresentOutcomeState = struct {
    reused: bool = false,
    outcome: TerminalPresentOutcome = .skipped,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,  // Leg only
    shared_surface_attachment_ready: bool = false, // Should carry conjunction
};
```

**Issue:** This struct carries the conjunction but is populated inconsistently:
- In `tryFastPresentExisting` (line 1696–1704): junction is populated correctly from `notePresentableAvailability`
- In `presentResultFromRefreshOutcomeState` (line 212–226): **BUG** — `shared_surface_attachment_ready` hardcoded to `false`

**Authority:** `CZH-B26` (ownership), `CZH-S24` (cohesion)

---

## Callsite Inventory

### Conjunction Derivation Callsites

| Callsite | File | Line | Flow | Helper Used | Stores Conjunction? | Result Field |
|----------|------|------|------|-------------|---------------------|---------------|
| `refreshPresentState` | `terminal_widget_presentation_runtime.zig` | 1571–1572 | Refresh → present-state snapshot | `notePresentableAvailability()` | ✓ `PresentationPresentState` | ✓ `shared_surface_attachment_ready` |
| `tryFastPresentExisting` | `terminal_widget_presentation_runtime.zig` | 1696–1698 | Reuse attempt | `notePresentableAvailability()` | ✓ `ReusePresentOutcomeState` | ✓ `shared_surface_attachment_ready` |
| `presentResultFromRefreshOutcomeState` | `terminal_widget_presentation_runtime.zig` | 212–226 | Refresh outcome fold | None (hardcoded false) | **✗** Lost in `TerminalPresentResult` | ✗ Hardcoded `false` |
| `readSharedSurfaceAttachmentReady` (diagnostic) | `terminal_widget_surface_state.zig` | 243–248 | Ad-hoc read (no present-state) | `hostSharedSurfaceAttachmentReadyFromPair()` | N/A (read-only) | N/A |

### Leg-only Callsites (Expected)

| Callsite | File | Line | Leg | Purpose |
|----------|------|------|-----|---------|
| `terminalPresentablePipelineReady()` | `terminal_widget_surface_state.zig` | 134–136 | Pipeline | Reuse gating (pipeline only, not conjunction) |
| `hostSurfaceTargetAvailable()` | `terminal_widget_surface_state.zig` | 143–145 | Host target | Leg observation in logs |

---

## Contraction Map

### Flow 1: Refresh Present Path (Presentable Refresh Cycle)
```
buildTerminalPresentPlan()
  ↓
runPresentableRefreshCycle()
  ↓
executeRefreshPresentFlow()
  ├─ runRefreshedPresentablePresentation()
  │   └─ refreshPresentState()          ← Route 3: Compute + store on PresentationPresentState
  │       ├─ notePresentableAvailability() ← Route 2a: Compute via canonical helper, store leg
  │       └─ return (PresentationPresentState with shared_surface_attachment_ready)
  │
  └─ classifyRefreshOutcome() + presentResultFromRefreshOutcomeState()
     └─ **BUG**: hostSharedSurfaceAttachmentReady COMPUTED but NOT carried to result
```

**Contraction target:** Thread conjunction through `RefreshOutcomeState` → `TerminalPresentResult`

---

### Flow 2: Reuse Fast Path (Presentable Reuse)
```
buildTerminalPresentPlan()
  ├─ .present_intent = .reuse
  ↓
tryFastPresentExisting()
  └─ notePresentableAvailability()  ← Route 2a: Compute via canonical helper, store leg
     └─ return ReusePresentOutcomeState with shared_surface_attachment_ready ✓ Correct
```

**No contraction needed:** Already canonical route.

---

## Hygiene Scope (CZH-799)

### Files to Audit for Debug/Probe Residue
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig` — check for obsolete `log enabled` checks or probe callsites
2. `src/ui/widgets/terminal_widget_surface_state.zig` — check for obsolete probes in state updates
3. `src/terminal/surface_attachment_contract.zig` — check for obsolete tests or debug patterns
4. `src/ui/renderer/presentable_contract.zig` — check for result aggregation debug code

### Authority Alignment (CZH-796)
1. Module doc strings: verify ownership claims match actual callsite authority
2. Function-level doc strings on helpers: verify naming restrictions align with locked semantics
3. Test-level doc strings: verify test IDs match canonical flow phases

---

## Validation Lock Targets

### Helper-Level Invariants (CZH-797)
- `hostSharedSurfaceAttachmentReady(pipeline, host)` == `pipeline and host` (comptime lock via test)
- `notePresentableAvailability()` output == `readSharedSurfaceAttachmentReady()` after call (comptime lock via test)
- RefreshOutcomeState conjunction field matches computed value before fold to result (runtime assertion opportunity)

### Integration Invariants (CZH-798)
- Refresh path: `PresentationPresentState.shared_surface_attachment_ready` == conjunction at time of `logUnavailable()` call (implicit by design)
- Reuse path: `ReusePresentOutcomeState.shared_surface_attachment_ready` == value from `notePresentableAvailability()` call (comptime lock via test)
- Result path: `TerminalPresentResult.shared_surface_attachment_ready` must be populated correctly for both refresh and reuse outcomes

---

## Tickets in Scope (CZH-792 through CZH-800)

1. **CZH-792** — Tighten seam docs: align doc strings with canonical routes identified above
2. **CZH-793** — Runtime: ensure conjunction propagates correctly through refresh outcome path
3. **CZH-794** — Surface-state bridge: no changes (already canonical)
4. **CZH-795** — Aggregation wording: align `TerminalPresentResult` field naming with leg vs conjunction roles
5. **CZH-796** — Ownership notes: audit module/function doc strings for authority alignment
6. **CZH-797** — Helper invariants: add comptime/runtime locks on canonical helper behavior
7. **CZH-798** — Integration invariants: lock flow-level guarantees across the three seams
8. **CZH-799** — Hygiene sweep: remove obsolete probes; sync authority to code
9. **CZH-800** — Validation: record results and gate handoff

---

## Authority References

- `docs/todo/core/CZH_S25_TICKETS.md` — Sprint scope
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — Attachment semantics lock
- `src/terminal/surface_attachment_contract.zig` — Canonical helper definition
- `src/ui/widgets/terminal_widget_presentation_state.zig` — PresentationState field storage
- `src/ui/renderer/presentable_contract.zig` — TerminalPresentResult host export struct
