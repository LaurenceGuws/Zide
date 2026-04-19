# CZH-811: Runtime/surface contraction audit + scope lock

Date: 2026-04-19  
Sprint: `CZH-S27`  
Batch: `CZH-B32`  
Gate target: `CZH-GATE-86`

## Executive Summary

Concrete contraction opportunities for CZH-B32 implementation cut. CZH-B31 verified all paths are canonical; CZH-B32 implements code simplifications and consolidations where current patterns can be tightened without behavior change. Focus on runtime callsites (CZH-813, CZH-814), surface-state bridge (CZH-815), and result folding (CZH-816).

## Contraction Opportunity Map

### Opportunity A: Leg/Conjunction Derivation Pattern Consolidation (CZH-813)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern (refresh path, lines 1589–1592):**
```zig
state.host_surface_target_available = renderer_presentable_host.terminalPresentableInfo(renderer) != null;
const shared_surface_attachment_ready = surface_state.notePresentableAvailability(state.host_surface_target_available);
state.shared_surface_attachment_ready = shared_surface_attachment_ready;
```

**Current Pattern (reuse path, lines 1718–1721):**
```zig
const host_surface_target_available = renderer_presentable_host.terminalPresentableInfo(renderer) != null;
const shared_surface_attachment_ready = surface_state.notePresentableAvailability(
    host_surface_target_available,
);
```

**Consolidation Target:**
- Both paths independently derive `host_surface_target_available` via `terminalPresentableInfo`
- Both then call `notePresentableAvailability` with that value
- **Contraction:** Introduce a helper that both computes the renderer info check and calls the canonical route, returning both leg and conjunction in one call
- This eliminates the dual-pattern and clarifies the canonical route boundary

**Scope:** Internal consolidation; no ABI/behavior change

---

### Opportunity B: Outcome State Consolidation in Fold Paths (CZH-814)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern (three fold functions, lines 206–251):**
- `presentResultFromOutcomeState`: Generic fold from outcome state fields
- `presentResultFromRefreshOutcomeState`: Specialized wrapper for refresh outcome, calls generic fold
- `presentResultFromReuseOutcomeState`: Specialized wrapper for reuse outcome, calls generic fold

**Consolidation Target:**
- Both `presentResultFrom*OutcomeState` wrappers extract fields and call the generic fold
- **Contraction:** Consolidate the wrapper logic or simplify the field extraction pattern
- Reduce parameter passing redundancy where outcome struct fields are decomposed then re-composed

**Scope:** Call-site simplification; no behavior change

---

### Opportunity C: Surface-State Read Bridge Pattern Lock (CZH-815)

**File:** `src/ui/widgets/terminal_widget_surface_state.zig`

**Current Pattern (line 249–254):**
```zig
pub fn readSharedSurfaceAttachmentReady(self: *const TerminalWidgetSurfaceState) bool {
    return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = self.presentation.terminal_presentable_pipeline_ready,
        .host_surface_target_available = self.presentation.host_surface_target_available,
    });
}
```

**Verification:** This pattern is already canonical (CZH-B31 verified). No code changes needed for this path.

**But:** Check callsites of `readSharedSurfaceAttachmentReady` for any parallel derivations or inconsistent reads.

**Contraction Target:**
- Audit all callsites to ensure they use this read bridge, not re-derived conjunction
- Document the pattern as the **only** read-only conjunction derive for widget surface state

**Scope:** Callsite audit + documentation; likely no code changes

---

### Opportunity D: Present-Result Conjunction Field Threading (CZH-816)

**File:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Current Pattern:**
- `RefreshOutcomeState` struct (lines 177–183): Does NOT carry conjunction (follows CZH-B30 design)
- `ReusePresentOutcomeState` struct (lines 192–201): Carries `shared_surface_attachment_ready` field
- `DirectPresentOutcomeState` struct (lines 185–189): Hardcoded both legs to `true`

**Contraction Target:**
- `RefreshOutcomeState` receives conjunction via separate parameter to `presentResultFromRefreshOutcomeState` (line 226)
- `DirectPresentOutcomeState` could be consolidated if direct-present paths always carry `true` for both legs (verify via callsite audit)
- **Opportunity:** If direct-present outcome fields are always `(true, true)`, the struct could be simplified or the fold pattern regularized

**Scope:** Verify field threading in all outcome fold callsites; likely minor pattern simplification

---

## Implementation Scope for CZH-813..CZH-816

| Ticket | Focus | File(s) | Concrete Edit Type | Behavior Risk |
|--------|-------|---------|-------------------|---------------|
| CZH-813 | Leg/conjunction consolidation | `terminal_widget_presentation_runtime.zig` | Add helper function; refactor 2 callsites | Low — consolidates existing patterns |
| CZH-814 | Outcome fold simplification | `terminal_widget_presentation_runtime.zig` | Simplify wrapper structure or field threading | Low — same result computation |
| CZH-815 | Surface-state read audit | `terminal_widget_surface_state.zig` + callsite inventory | Audit + doc lock | None — verification only |
| CZH-816 | Result conjunction threading | `terminal_widget_presentation_runtime.zig` | Verify field values; possible struct simplification | Low — same fields computed |

---

## CZH-819 Hygiene Scope

Files to audit for stale probe/debug residue during contraction work:
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
2. `src/ui/widgets/terminal_widget_surface_state.zig`
3. `src/ui/renderer/renderer_presentable_host.zig` (if touched for outcome state)
4. `src/terminal/surface_attachment_contract.zig` (canonical helpers)

---

## Behavior-Freeze Guardrails (CZH-S27)

**Default assumption:** All tickets preserve behavior unless explicitly marked.

**Behavior change exception process:**
1. If a ticket encounters a behavior issue during contraction, isolate it
2. Document it explicitly in this audit file or queue docs
3. Mark ticket and commit with behavior-fix signpost
4. Include rationale and verification in checkpoint

**Current status:** No behavior issues anticipated; contractions are consolidations of existing canonical patterns.

---

## Ready for CZH-812

✓ Audit complete. Four concrete contraction opportunities identified.  
✓ Scope locked: CZH-813 (helper consolidation) + CZH-814 (fold simplification) + CZH-815 (read audit) + CZH-816 (field threading).  
✓ No showstoppers identified. All paths already canonical from CZH-B31.  
✓ Proceeding with doc tightening (CZH-812) and implementation cuts (CZH-813..CZH-816).
