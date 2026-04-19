# CZH-799: Scoped probe/doc hygiene sweep + authority sync

Date: 2026-04-19  
Sprint: CZH-S25  
Batch: CZH-B30  
Gate target: CZH-GATE-84

## Hygiene Scan Results

### Touched Files Audit

**Scope:** Files modified in CZH-791 through CZH-798 batch work.

#### 1. `src/terminal/surface_attachment_contract.zig`
**Probe residue:** None  
**Debug imports:** None  
**Investigation patterns:** None  
**Authority alignment:** ✓ Module doc and function docs accurately reflect canonical helper semantics (CZH-S18, CZH-791)  
**Verdict:** Clean — no probes removed. Authority wording matches implementation.

#### 2. `src/ui/widgets/terminal_widget_surface_state.zig`
**Probe residue:** None  
**Debug imports:** None  
**Investigation patterns:** None  
**Authority alignment:** ✓ Module doc and method docs correctly name conjunction propagation phases and reporting carriers (CZH-S22, CZH-S23)  
**Verdict:** Clean — no probes removed. Authority wording matches implementation.

#### 3. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
**Probe residue:** None (debug_geometry is part of permanent operator telemetry infrastructure, not a temporary probe)  
**Debug imports:** `terminal_debug_geometry` (lines 55, 579) — part of enabled debug subsystem, not investigation-only  
**Investigation patterns:** None  
**Authority alignment:** ✓ Module doc, struct docs, and function docs accurately reflect conjunction propagation and ownership split (CZH-S22, CZH-S23, CZH-B26)  
**Verdict:** Clean — no probes removed. Authority wording matches implementation.

#### 4. `src/ui/renderer/presentable_contract.zig`
**Probe residue:** None  
**Debug imports:** None  
**Investigation patterns:** None  
**Authority alignment:** ✓ Struct doc accurately reflects host export/aggregation role (CZH-B26, CZH-791)  
**Verdict:** Clean — no probes removed. Authority wording matches implementation.

#### 5. `src/ui/widgets/terminal_widget_draw.zig`
**Probe residue:** None  
**Debug imports:** None  
**Investigation patterns:** None  
**Authority alignment:** ✓ Module doc clearly states draw vs runtime ownership split and conjunction propagation boundaries (CZH-S22, CZH-S24)  
**Verdict:** Clean — no probes removed. Authority wording matches implementation.

#### 6. `docs/todo/core/CZH_791_SEAM_CONTRACTION_AUDIT.md`
**Authority alignment:** ✓ Authority references match implementation canonical routes and existing tests  
**Verdict:** Clean — new authority document aligns with code.

### Summary

**Total files audited:** 6  
**Probes removed:** 0  
**Probes kept:** 0 (no probes found)  
**Authority corrections:** 0 (all authority wording already aligned)  
**Authority enhancements:** 5 (doc strings tightened in CZH-792)  
**New authority documents:** 1 (`CZH_791_SEAM_CONTRACTION_AUDIT.md`)

### Probe Removal Rationale

No investigation-only probes were identified in the touched product code. The `terminal_debug_geometry` import in `terminal_widget_presentation_runtime.zig` is part of the permanent operator telemetry infrastructure (samples collection), not a temporary probe. It remains as-is.

### Authority Sync Status

All module-level and function-level doc strings in touched files now explicitly reference the canonical helper routes and CZH-791 batch work. The following doc strings were enhanced:

1. `surface_attachment_contract.zig` — added CZH-791 reference to canonical helper functions
2. `terminal_widget_surface_state.zig` — added CZH-791 reference to conjunction propagation phases
3. `terminal_widget_presentation_runtime.zig` — added CZH-791 reference to canonical routes throughout
4. `presentable_contract.zig` — added CZH-791 reference to host export role
5. `terminal_widget_draw.zig` — added CZH-791 reference to ownership split

No authority wording required removal or correction — all docs were already accurate and have been enhanced with explicit canonical route references.

## Verdict

**All touched code is clean.** Prod paths carry no stale investigation probes or debug residue. Authority wording is fully aligned with implementation and explicitly names canonical routes per CZH-791 audit. Ready for CZH-GATE-84 checkpoint.
