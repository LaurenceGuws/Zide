# CZH-1229: Hot-Path Hygiene Audit Map

**Date:** 2026-04-21  
**Scope:** Real app execution paths for investigation logging, debug capture writes, raw pointer telemetry, and avoidable copy churn.

## Executive Summary

Most high-impact hot-path contamination has been addressed through prior `CZH-B78` work documented in `ANDROID_RENDER_THREAD_CONTRACT.md` (subcategories 1-7). This audit confirms current state: **core hot paths are already clean**.

**Key finding:** Investigation logging, debug capture, and trace infrastructure are already properly gated. No unconditional investigation logging found in product hot paths during audit. Remaining work is either:
- Non-issues (properly gated, error-path only)
- Insufficient evidence for cleanup (would require measurement)
- Deferred to next phase (requires broader architectural scope)

---

## Cleaned Categories (Per Android Contract)

These categories are accepted as meeting hygiene standards:

### 1. Live Font/Scale/Atlas Path
**Status:** ✅ Accepted Android boundary (2026-04-12)

**Files:**
- `src/ui/renderer/font_manager.zig`
- `src/ui/renderer/font_runtime.zig`

**Findings:**
- Live scale updates now use cheap state mutation without destroying full font cache
- Expensive font rebuild is staged behind committed-size lifecycle instead of executing on every interaction step
- Terminal font rendering now separates CPU preparation from GPU adoption

**Classification:** `keep-as-correctness` (cache lifecycle is product state)

### 2. Render-Entry Submission Path
**Status:** ✅ Checkpoint reached (multiple cuts landed)

**Files:**
- `src/platform/android_runtime_bridge.zig` (Android-local)
- `src/ui/renderer/renderer_frame_host.zig` (shared)

**Findings:**
- Stageable input/viewport updates now mark redraw intent instead of synchronous frame submission
- Lifecycle-critical direct submit paths routed through explicit seam
- Remaining direct-submit authority explicitly named

**Classification:** `keep-as-correctness` (frame readiness and submission ownership)

### 3. Grid Resize in Draw Flow
**Status:** ✅ Checkpoint reached

**Files:**
- `src/ui/widgets/terminal_widget.zig`
- `src/platform/android_runtime_bridge.zig`

**Findings:**
- Terminal grid fit now dirty-driven; paced frame loop owns commit
- Product-fit flush moved out of draw path fallback into explicit pre-draw seam
- Cell-metric-only updates separated from grid reflow

**Classification:** `keep-as-correctness` (grid resize is terminal state)

### 4. Terminal Widget Presentation Invalidation Path
**Status:** ✅ Multiple cuts landed (not reopening without concrete blocker)

**Files:**
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_state.zig`
- `src/ui/widgets/terminal_widget.zig`

**Findings:**
- Invalidation now preserves cause explicitly (geometry, content, overlay, availability families)
- Execution path selection separated from cache-state advancement
- Presentation update planning centralized; outcome classification routed through helpers
- Fast-reuse path no longer hard-codes synthetic results

**Classification:** `keep-as-correctness` (presentation state machine is product authority)

### 5. Backend Frame Begin/Submit Mechanics
**Status:** ✅ Checkpoint reached

**Files:**
- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer/android_gles_backend.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`

**Findings:**
- One-time warmup/initialization separated from steady-state frame begin
- Submit-time replay work named explicitly (frame-critical vs debug capture)
- Capture/readback paths isolated from ordinary product submission
- Text-render uniform sync now dirty-driven
- Frame entry now reads honestly as acquire → readiness-check → setup/clear

**Classification:** `keep-as-correctness` (frame begin/submit is backend contract)

### 6. Debug/Observability Contamination of Product Execution
**Status:** ✅ Multiple cuts landed

**Files:**
- `src/ui/renderer/present_feedback_state.zig`
- `src/ui/renderer/present_feedback_host.zig`
- `src/ui/renderer/present_trace_runtime.zig`
- `src/ui/renderer/present_capture_host.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Findings:**
- Debug capture samples now gated behind explicit `samples_enabled` flag
- Optional `PresentTrace` counters advance only when `renderer.present` tag is enabled
- Correctness feedback (`FrameFamilySummary`) remains always-on, separate from optional trace
- Capture state ownership explicit and routed through host seam
- Font-prep, zoom-path, input/hover operator telemetry all gated before formatting
- Logger boundary hardened: `logf()` returns before formatting when tag is disabled

**Classification:** `keep-as-operator-telemetry` (gated, with disabled cost near-zero)

### 7. Remaining Android Host/UI-Thread Contamination
**Status:** ✅ Stop reading marker met (further extraction without concrete blocker risks cosmetic churn)

**Files:**
- `android/terminal-host/app/src/main/java/.../ZideActivity.java`
- `android/terminal-host/app/src/main/java/.../ShellSessionController.java`
- `android/terminal-host/app/src/main/java/.../ShellInputView.java`

**Findings:**
- Debug/status presentation split into dedicated controllers
- Viewport/inset authority explicit and not periodic
- Product shell refresh and debug refresh now separate operations
- Install-state transitions route through explicit activity seam
- View-mode transitions centralized
- Lifecycle/callback aftermath operations grouped through explicit seams

**Classification:** `keep-as-correctness` (Android lifecycle and gesture ownership)

---

## Current State: Cleanup Targets Audit

### ❌ REJECTED: Frame Completion and Telemetry Formatting
**Status:** Verified clean, no cleanup target

**File:** `src/ui/renderer/renderer_frame_host.zig` (305 lines total, 40 code)

**Audit result:** 
- No diagnostic logging or telemetry formatting in hot-path functions
- `beginFrameHost()`: only state resets, window dimension updates
- `finishFrameSubmission()`: only state mutation and capture clearing
- No `logf()`, no string formatting, no conditionaltelemetry emission
- Trace state updates delegated to other modules (present_trace_runtime)

**Conclusion:** Rejected as cleanup target. Code is already clean.

---

### ✅ CLEAN: Shell Session Polling and State Management
**Status:** Verified clean, no cleanup target

**Files audited:**
- `src/terminal/core/session/runtime.zig` (167 lines) — facade only, delegates to other modules
- `src/terminal/core/session/runtime_lifecycle.zig` — implements `poll()`, no investigation logging
- `src/app/terminal/terminal_frame_pacing_runtime.zig` — metrics observation only

**Audit result:**
- No `logf()` calls in poll implementation
- No investigation state mutations
- No cycle-counting or debug capture on poll path
- Generation/publication updates are correctness-necessary

**Conclusion:** No cleanup needed. Poll paths are already clean.

---

### ✅ CLEAN: Input Latency and IME Paths
**Status:** Verified clean, no cleanup target

**Files audited:**
- `src/app/terminal/terminal_widget_input_runtime.zig` — failure-path logging only
- `src/terminal/core/session/input.zig` (370 lines) — no investigation logging in hot paths
- `src/platform/input_events.zig` — platform layer, no product investigation code

**Audit result:**
- Input/hover operator telemetry already gated before formatting
- Control+click file opening logs only on failure (appropriate)
- No unconditional investigation state mutations on input path
- No cycle-counting or debug capture in IME/composition paths

**Conclusion:** No cleanup needed. Input paths already meet hygiene standard.

---

### ⚠️ DEFERRED: Terminal Widget Draw Paths
**Status:** Code organization clean, measurement-dependent

**Files audited:**
- `src/ui/widgets/terminal_widget_draw.zig` (381 lines)
- `src/ui/widgets/terminal_widget_draw_grid.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`

**Audit result:**
- Warning-level logging found, but only in error path (font cache miss): `log.logf(.warning, "terminal_glyph_prep_adopt_target_missing ...")` — appropriate to keep
- Draw plan construction is straightforward; no obvious redundant computations found
- No investigation logging in main draw loop
- Copy operations appear necessary for draw-command accumulation

**Conclusion:** No unconditional hot-path waste identified. Any further optimization would require performance measurement to justify refactoring.

---

### ⚠️ DEFERRED: Editor Rendering and Snapshot Paths
**Status:** No investigation residue found; architecture out of scope

**Files audited:**
- `src/editor/render/cache.zig`
- `src/editor/snapshot.zig` (TODO: highlight population is future feature, not residue)
- `src/app/mode_adapter_parity.zig`

**Audit result:**
- No investigation logging in editor render cache
- Failure logging in snapshot/adapter paths is appropriate error-level reporting
- Snapshot building logic is straightforward; no obvious investigation state
- Copy operations at limit boundaries are part of feature design, not waste

**Conclusion:** No hygiene cleanup identified. Code is architecturally correct. Do not refactor snapshot/copy boundaries without separate correctness/performance motivation.

---

### F. Presentation Sample and Trace Infrastructure
**Status:** ✅ Already audited and gated

**Files:**
- `src/ui/renderer/present_trace_runtime.zig`
- `src/ui/renderer/present_feedback_state.zig`
- `src/ui/renderer/present_capture_state.zig`

**Current state:**
- All trace operations (`noteFrameFamilyTouch`, `noteSampleSectionCommandGroupBegin`, etc.) gated by `if (!self.present.trace_enabled) return`
- Trace enabled only when `renderer.present` logger tag is active
- Sample section frame-family tracking properly separated from correctness feedback

**Classification:** `keep-as-operator-telemetry` (already properly gated)

---

### G. Widget Invalidation and State Advancement
**Status:** ✅ Verified clean, no cleanup target

**Files:**
- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_surface_state.zig`

**Scope:**
- Invalidation request paths and their cost
- Cache-state advancement in refresh vs reuse paths
- Any investigation state mutation during invalidation

**Current state found:**
- Invalidation causes explicit and named (geometry, content, overlay, availability)
- State advancement routed through explicit helpers

**Audit result:**
- No investigation logging or debug capture mutation in invalidation paths
- Invalidation causes remain explicit and correctness-owned
- Cache-state advancement routes are ownership-consistent with prior accepted boundaries

**Conclusion:** Keep as correctness. No hygiene cleanup target.

---

## Recommended Next Step

No executable hygiene cleanup targets were found from code inspection alone.

The next step is measurement-driven:
- collect bounded performance attribution in the audited hot paths
- identify one concrete artifact with defensible runtime cost
- then execute code cleanup against that measured artifact

---

## Non-Issues (Already Clean or By-Design)

### Error-Path Logging (Appropriate)
**Files:** `src/app/`, `src/terminal/`

**Finding:** Warnings and error-level logs on failure paths (file I/O, snapshot copy failures, icon decode failures) are appropriate and should remain.

**Classification:** `keep-as-operator-telemetry` (only on failure, not hot path)

---

### Debug-Only Tools (Out of Product Path)
**Files:** `src/ui/widgets/terminal_widget_debug_capture.zig`, `src/ui/widgets/terminal_widget_debug_geometry.zig`, `src/app/mouse_debug_log.zig`

**Finding:** These are debug-only helpers, not part of product hot paths.

**Classification:** `keep-as-debug-only` (not in product paths)

---

## Summary Table

| Category | Files | Status | Classification | Action |
|----------|-------|--------|-----------------|--------|
| Font/scale/atlas | `font_*.zig` | ✅ Accepted | keep-as-correctness | None |
| Frame submission | `renderer_frame_host.zig`, Android bridge | ✅ Accepted | keep-as-correctness | None |
| Grid resize | Terminal widget, Android bridge | ✅ Accepted | keep-as-correctness | None |
| Presentation invalidation | Terminal widget presentation | ✅ Accepted | keep-as-correctness | None |
| Backend frame mechanics | Backend `*.zig` | ✅ Accepted | keep-as-correctness | None |
| Debug/observability | `present_*_*.zig` | ✅ Accepted | keep-as-operator-telemetry | None |
| Android UI thread | Java host | ✅ Accepted | keep-as-correctness | None |
| Frame telemetry formatting | `renderer_frame_host.zig` | ✅ Clean | already correct | No cleanup target |
| Shell polling | Session runtime | ✅ Clean | already correct | No cleanup target |
| Input latency | Input runtime | ✅ Clean | already correct | No cleanup target |
| Draw path copies | Widget draw | ✅ Clean | already correct | Deferred to measurement |
| Editor rendering | Editor cache/snapshot | ✅ Clean | already correct | No cleanup target |

---

## Audit Outcome: No Executable Cleanup Targets

**Result:** Systematic audit of all identified hot-path categories completed. **No unconditional investigation logging, debug capture updates, or avoidable copy churn found in product paths.**

### Finding by Category

All categories audited fell into one of two classes:

**Class 1: Already Accepted (Prior Work)**
- Live font/scale/atlas
- Frame submission mechanics
- Grid resize in draw flow
- Presentation invalidation
- Backend frame mechanics
- Debug/observability (all properly gated)
- Android host/UI thread

**Class 2: Verified Clean (This Audit)**
- Frame telemetry formatting: ✅ no logging/formatting in hot path
- Shell polling: ✅ no investigation logging
- Input latency: ✅ no unconditional state mutations
- Terminal widget draw: ✅ error-path logging only
- Editor rendering: ✅ appropriate failure logging only

### CZH-1230 and CZH-1231 Status

These tickets cannot be unambiguously scoped based on hygiene audit alone. Per requirements, executable cleanup tickets must name **concrete file:line, function, artifact, classification, and code change**.

**This audit found:** No such targets.

**Path forward:** Require either
1. Measurement data identifying hot-path cost with specific attribution, or
2. Architect redefine of scope beyond hygiene (e.g., refactoring for correctness, optimization)

---

## Architectural Implication

**Success Finding:** Hot-path investigation logging and debug contamination have been successfully addressed in prior work (prior sprint hygiene cuts and Android render-thread contract work). **The shared core is clean.**

**What This Means:**
- Performance baseline work (`CZH-1234` validation) should focus on measuring absolute product-path cost, not on "before/after cleanup" comparison
- Future correctness bugs or optimization opportunities will need separate authorization; they are out of scope for hygiene sprint
- Hygiene baseline is achieved; no further investigation-logging cleanup is identifiable from code inspection alone

## Ticket Disposition

**CZH-1229** (This ticket): Audit complete. Findings documented. **Blocked on downstream scope clarification.**

**CZH-1230 and CZH-1231:** Cannot be unambiguously executed from hygiene audit. **Awaiting Architect definition.**

**CZH-1232, CZH-1233, CZH-1234:** Scoped per sprint plan; not dependent on this audit's findings.
