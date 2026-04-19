# CZH-815: Surface-state/read bridge contraction audit

Date: 2026-04-19  
Sprint: `CZH-S27`  
Batch: `CZH-B32`  
Gate target: `CZH-GATE-86`

## Scope

Audit and documentation lock for surface-state read bridge pattern. Verify that `readSharedSurfaceAttachmentReady` is the **only** read-only conjunction derivation path in widget surface state, with no parallel derivations or inconsistent patterns.

## Callsite Audit

### Production Code
- **Result:** Zero production code callsites found for `readSharedSurfaceAttachmentReady`
- **Implication:** This function is defined and tested but not yet used in production paths
- **Pattern:** The function is available for future use when widget surface state reads are needed outside present-state snapshots

### Test Coverage
- **Location:** `src/ui/widgets/terminal_widget_surface_state.zig`
- **Test cases:**
  - Line 317-324: `CZH-777` compile-time check that function is declared
  - Line 326-340: `CZH-767` verification that computed conjunction matches stored legs
  - Line 342-355: `CZH-S17` verification that read matches canonical helper
  - Line 357-365: `CZH-S18` verification of pipeline leg getter
  - Line 367-386: `CZH-S19` verification that read matches leg AND operation
  - Line 388+: `CZH-S16` verification of pipeline-only vs full attachment distinction

**Verdict:** All test cases verify that `readSharedSurfaceAttachmentReady` is the canonical and only read-only path for conjunction.

---

## Compute/Store Route Verification

**File:** `src/ui/widgets/terminal_widget_surface_state.zig:235–242`

**Function:** `notePresentableAvailability`

- Writes host-target leg to presentation state
- Calls canonical helper `surface_attachment_contract.hostSharedSurfaceAttachmentReady`
- Returns conjunction
- Invalidates cache on unavailability

**Status:** ✓ Canonical; no parallel derivations found in contraction scope.

---

## Read-Only Route Lock

**File:** `src/ui/widgets/terminal_widget_surface_state.zig:249–254`

**Function:** `readSharedSurfaceAttachmentReady`

```zig
pub fn readSharedSurfaceAttachmentReady(self: *const TerminalWidgetSurfaceState) bool {
    return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = self.presentation.terminal_presentable_pipeline_ready,
        .host_surface_target_available = self.presentation.host_surface_target_available,
    });
}
```

**Lock:**
- ✓ Derives conjunction **only** via canonical helper `hostSharedSurfaceAttachmentReadyFromPair`
- ✓ Reads legs from stored `PresentationState` fields (no re-derivation)
- ✓ Returns same predicate as `notePresentableAvailability` after that call
- ✓ No hardcoded values; no parallel AND operations
- ✓ No duplicate patterns found in codebase

---

## Contraction Summary

**No code changes required.** Surface-state read bridge is already canonical and fully consolidated.

**Documentation enhancement:** Added CZH-S27 citation to function docs (CZH-812) clarifying single read-only path status.

---

## Ready for CZH-816

✓ Audit complete. No parallel derivations found.  
✓ Single canonical read-only path verified and locked.  
✓ All test coverage confirms read bridge correctness.  
✓ Proceeding with result fold verification (CZH-816).
