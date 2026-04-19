# CZH-891: Callback Extraction Audit + Interface Map

**Status:** `in_progress`  
**Scope:** Identify orchestration functions requiring callback extraction and define interface shapes.  
**Authority:** CZH-S35 sprint, terminal orchestrator ownership completion via callbacks.

## Current State (Authoritative)

The seam is already extracted into terminal-owned orchestration with widget-owned
hook execution, expressed as Zig `ctx` + comptime `Hooks` rather than runtime
fn-pointer tables.

Terminal-owned entrypoints:

1. Refresh orchestration:
   - `src/terminal/presentation_runtime.zig`: `executeRefreshPresentFlow(rows, cols, ctx, Hooks)`
2. Reuse decision + fold helpers:
   - `checkReuseEligibility`, `reuseSuccessOutcome`, `presentResultFromReuseOutcomeState`
3. Direct-present decision + fold helpers:
   - `checkDirectPresentEligibility`, `classifyDirectPresentOutcome`

Widget-owned integration facade:

1. `src/ui/widgets/terminal_widget_presentation_runtime.zig` builds `ctx` and `Hooks` and
   delegates orchestration/classification/fold to terminal.
2. Widget retains GPU drawing, cache mutation, renderer/shell integration, and
   operator reporting wiring.

## What Remains (This Sprint)

The remaining work is not “extract callbacks”; it is “reduce boundary payload
width and harden contracts”:

1. Remove implicit ctx-shape requirements across the renderer-refresh host wrapper.
2. Collapse “argument soup” booleans/lengths into small structs for reuse/direct eligibility.
3. Lock invariants with helper-level and integration-level tests.
4. Keep the widget runtime as a facade (no duplicated decision/fold seams).

## Architecture Outcome

**Terminal-owned:**
- Orchestration, classification, folding, geometry computation
- Attachment leg/conjunction computation helpers

**Widget-retained:**
- GPU drawing execution
- State mutation
- Integration with renderer/shell
- Facade pattern: build `ctx` + `Hooks` then call terminal-owned helpers

## Next Steps

- CZH-911: Boundary audit + reduction map (this sprint)
- CZH-912: Authority tightening documentation (doc-only)
- CZH-913..916: Reduce refresh/reuse/direct boundary surfaces + widget facade contraction
- CZH-917/918: Helper-level + integration boundary invariants
