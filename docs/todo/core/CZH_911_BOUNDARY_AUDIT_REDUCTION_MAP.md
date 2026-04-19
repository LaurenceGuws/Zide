# CZH-911: Boundary Audit + Reduction Map

**Status:** `in_progress`  
**Lane:** `core_czh`  
**Sprint:** `CZH-S37`  
**Batch:** `CZH-B42` (toward `CZH-GATE-96`)  
**Scope:** Audit terminal↔widget callback/data-flow surfaces and identify reducible payload fields/params.  
**Hard rule:** Behavior freeze; map only. No semantic changes.

## Goal

The terminal layer owns orchestration/decision/folding; the widget layer is the
integration facade that executes GPU work, mutates widget-local state, and
bridges renderer/shell concerns.

This ticket records the current seam surfaces and a concrete reduction cut-list
to apply in order (`CZH-913`..`CZH-916`) without changing behavior or host ABI.

## Seam Inventory (Current)

### Refresh Path (terminal-owned orchestration, widget-owned execution)

Terminal entrypoint:

- `src/terminal/presentation_runtime.zig`
  - `executeRefreshPresentFlow(rows, cols, ctx, Hooks) -> TerminalPresentResult`
  - `Hooks` required shape:
    - `runCycle(ctx) -> TerminalPresentableRefreshExecutionResult`
    - `runPresentation(ctx, cycle: TerminalPresentableRefreshExecutionResult) -> RefreshedPresentablePresentationResult`

Widget facade that builds `ctx` and `Hooks`:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
  - `executeRefreshPresentFlow(...) -> TerminalPresentResult`
  - Local `RefreshCtx` currently carries (verbatim field set):
    - widget pointer, shell pointer, renderer, terminal view model, view geometry
    - `view_cells_len`
    - hover/composition state (`hover_link_id`, `composing_active`, `composing_hash`)
    - selection state (`start_line`)
    - cursor/blink state (`draw_cursor`, `cursor`, `cursor_style`, `blink_style`, `blink_time`)
    - `has_kitty`
    - `surface_update_plan`
    - present notification callback context (`note_present_ctx`)
    - `note_present` callback is captured out-of-struct (anytype limitation)

Refresh callback chain that is sensitive to payload shape:

- `src/ui/renderer/renderer_presentable_host.zig`
  - `runTerminalPresentableRefreshExecution(renderer, plan, ctx, Hooks) -> TerminalPresentableRefreshExecutionResult`
  - Current shape requirement: `ctx` must have a writable `result: *TerminalPresentableRefreshExecutionResult`
    field (assigned internally so `Hooks.executeUpdate(...)` can populate timing).

### Reuse Path (terminal-owned eligibility + folding, widget-owned execution)

Terminal entrypoints:

- `src/terminal/presentation_runtime.zig`
  - `checkReuseEligibility(plan, view_cells_len, shared_surface_attachment_ready, sync_updates_active, supports_reuse_without_sync) bool`
  - `reuseSuccessOutcome() -> ReusePresentOutcomeState`
  - `presentResultFromReuseOutcomeState(outcome_state, timing) -> TerminalPresentResult`
  - `presentDraw(...)` delegates to renderer-presentable host with reuse-mode tagging.

Widget execution:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
  - `tryFastPresentExisting(...) -> ReusePresentOutcomeState`
    - computes attachment legs/conjunction, asks terminal for eligibility
    - executes backdrop + `presentDraw(...)`
    - advances presentation cache via `advancePresentationCache(...)`
  - `runFastPresentIfAvailable(...) -> TerminalPresentResult` folds only on success

### Direct-Present Path (terminal-owned eligibility/classification/folding, widget-owned draw)

Terminal entrypoint:

- `src/terminal/presentation_runtime.zig`
  - `checkDirectPresentEligibility(rows, cols, view_cells_len) bool`
  - `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState`
  - `presentResultFromOutcomeState(...) -> TerminalPresentResult`

Widget execution:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
  - `directPresent(...) -> DirectPresentResult` executes GPU draw and present notifications.

## Reduction Targets (Cut List)

This section is intentionally concrete: each bullet is a reduction candidate
that can be applied without behavior change.

### CZH-913 (Refresh Callback Surface Reduction)

1. Remove redundant refresh-callback carriers where they are derivable:
   - `view_cells_len` can be derived from `terminal_view.cells.len` in the widget facade.
2. Minimize refresh-context carriage into the terminal callback hook:
   - Split refresh execution into two small callback inputs rather than a monolithic `RefreshCtx`
     that must simultaneously satisfy cycle, presentation, and notification needs.
3. Harden the refresh execution bridge to avoid hidden ctx-shape requirements:
   - Eliminate the implicit `ctx.result` field requirement in
     `renderer_presentable_host.runTerminalPresentableRefreshExecution`.
     Replace with an explicit out-parameter or return value wiring so the hook ctx is not mutated
     by the host wrapper.
4. Tighten refresh path result threading:
   - Ensure the only refresh inputs used by terminal folding are the refresh tag and timing
     (`TerminalPresentableRefreshExecutionResult.refresh` + `.timing`) plus
     the computed conjunction carrier (`shared_surface_attachment_ready`).

### CZH-914 (Reuse Callback Surface Reduction)

1. Collapse bool/len “argument soup” at the terminal reuse eligibility boundary:
   - Replace `(view_cells_len, shared_surface_attachment_ready, sync_updates_active, supports_reuse_without_sync)`
     with a single small struct representing reuse eligibility inputs.
2. Avoid duplicating attachment state derivation paths:
   - Reuse the canonical attachment compute/read helpers (`computeHostSurfaceAttachmentState`,
     `notePresentableAvailability`, `readSharedSurfaceAttachmentReady`) as the only conjunction sources.

### CZH-915 (Direct-Present Callback Surface Reduction)

1. Collapse direct-present eligibility inputs into a single small struct:
   - Replace `(rows, cols, view_cells_len)` with a compact “view draw admissibility” struct.
2. Reduce direct-present notification call argument width (internal surface):
   - Prefer passing a single “present sample” struct to the `note_present` callback rather than
     many scalar fields, so callers don’t grow signature drift.

### CZH-916 (Widget Facade Contraction)

1. Once refresh/reuse/direct surfaces are reduced, contract the widget facade to:
   - gather widget-local state (shell/renderer, view model, geometry, cursor/composition)
   - call terminal-owned decision/fold helpers
   - execute GPU work and cache mutation strictly in the widget layer
2. Ensure widget does not duplicate terminal-owned classification/folding state:
   - no parallel outcome derivation; only consume terminal helpers.

## Non-Goals / Guard Rails

- No host ABI / C export changes.
- No behavior changes (no semantic drift).
- No compat/fallback branches.
- No ticket lineage in source comments; keep lineage in `docs/todo/` only.

