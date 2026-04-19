# `CZH-S9` checkpoint — `CZH-GATE-68`

Date: 2026-04-19  
Sprint: `CZH-S9`  
Batch: `CZH-B14`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S9`
- Batch: `CZH-B14`
- Gate: `CZH-GATE-68` — **submitted for Architect review**
- Focus: widget presentation present-plan generation limb consumes
  `surface_contract.publicationGenerationDiffersFromLastSurfaceRender`; no ABI or
  draw-policy change.

## Scope summary

- **CZH-646:** audit — `terminal_widget_presentation_runtime.buildTerminalPresentPlan`.
- **CZH-647:** `publicationGenerationDiffersFromLastSurfaceRender` in
  `surface_contract.zig`.
- **CZH-648:** present-plan uses helper for publication vs `lastRenderGeneration`.
- **CZH-649:** alias test + `TERMINAL_SURFACE_CONTRACT.md` + queue landed note.
- **CZH-650:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-646 | `a501dcd8` |
| CZH-647 | `6aa45e5c` |
| CZH-648 | `2f3ce267` |
| CZH-649 | `6c672952` |

`CZH-650` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S9_CHECKPOINT.md`).

## VALIDATION (engineer run, 2026-04-19)

- `zig build` — PASS  
- `zig build test` — PASS  
- `zig build -Dmode=terminal` — PASS  
- `zig build -Dmode=editor` — PASS  
- `zig build test-config` — PASS  
- `zig build test-editor` — PASS  
- `zig build test-terminal-replay-all` — PASS  

Android Gradle guard — **SKIP** (lane paused).

## Blocked by Architect review needed

- **true** (for `CZH-GATE-68` acceptance).
