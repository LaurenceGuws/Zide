# CZH-S36 Checkpoint — Execution-Hook Purity and Facade Tightening

**Sprint:** CZH-S36  
**Batch:** CZH-B41  
**Gate:** CZH-GATE-95  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

All 10 tickets executed in order. No behavior changes. No ABI changes. No fallback branches introduced.

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-901 | `bca02dda` | Seam audit — identify `refreshPresentState` mutation ambiguity and informal hook interface |
| CZH-902 | `0263c3e5` | Authority tightening — update module docs to reflect terminal ownership of orchestration |
| CZH-903 | `8513f2b7` | Refresh hook signature tightening — make `refreshPresentState` pure, widget calls `advancePresentationCache` |
| CZH-904 | `39223018` | Reuse/direct hook signature tightening — verify minimal, formalize `executeRefreshPresentFlow` hook interface in doc |
| CZH-905 | `51a241d3` | Widget facade contraction — normalize import section comments to present-tense architecture |
| CZH-906 | `54fd87ee` | Comment and docstring normalization — remove stale historical comments from touched files |
| CZH-907 | `bd419c6e` | Helper-level invariants for `refreshPresentState` purity and tightened hook behavior |
| CZH-908 | `d611fa87` | Integration invariants for callback boundary compatibility and CZH-903 boundary |
| CZH-909 | `f0c106cf` | Hygiene sweep — remove ticket IDs from test names in touched files |
| CZH-910 | (this commit) | Validation packet + gate handoff |

## Validation

- `zig build`: clean (no warnings, no errors)
- `zig build test`: all tests pass

## Key Changes

### CZH-903: `refreshPresentState` purity

`refreshPresentState` in `src/terminal/presentation_runtime.zig` was reduced from 14 to 7 parameters. The `notePresentationUpdated` side effect (widget-layer state mutation) was removed. Widget caller (`runRefreshedPresentablePresentation`) now calls `advancePresentationCache` before `refreshPresentState`. Terminal function is now pure state computation only.

### CZH-904: Hook interface formalization

`executeRefreshPresentFlow` hook interface was informal (comment-only). Doc now explicitly specifies the required `runCycle` and `runPresentation` signatures.

### CZH-907/908: Test coverage

Added 5 tests in `src/terminal/test_presentation_runtime.zig` covering `refreshPresentState` purity. Added 3 tests in `src/ui/widgets/test_presentation_runtime_integration.zig` covering `PresentationPresentState` boundary consistency.

## Ownership Map Verification

All functions from CZH-901 seam audit confirmed clean:

- Terminal layer: pure decision, classification, folding, geometry, orchestration (via Hooks)
- Widget layer: execution (GPU drawing, state mutation, renderer integration)
- No terminal-layer functions with widget-layer side effects remaining

## Files Touched

- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/CZH_S36_CZH901_SEAM_AUDIT.md` (created in CZH-901)
- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/implementation.md`
- `docs/AGENT_HANDOFF.md`
