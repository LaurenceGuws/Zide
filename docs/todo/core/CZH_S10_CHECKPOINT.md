# `CZH-S10` checkpoint — `CZH-GATE-69`

Date: 2026-04-19  
Sprint: `CZH-S10`  
Batch: `CZH-B15`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S10`
- Batch: `CZH-B15`
- Gate: `CZH-GATE-69` — **submitted for Architect review**
- Focus: widget presentation present-plan **clear-generation** limb consumes
  `surface_contract.clearGenerationDiffersFromLastSurfaceRenderClear`; no ABI or
  draw-policy change.

## Scope summary

- **CZH-651:** audit — `buildTerminalPresentPlan` clear-generation limb.
- **CZH-652:** `clearGenerationDiffersFromLastSurfaceRenderClear` in
  `surface_contract.zig`.
- **CZH-653:** present-plan routes clear limb through helper.
- **CZH-654:** alias test + `TERMINAL_SURFACE_CONTRACT.md` + queue landed note.
- **CZH-655:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-651 | `116636d4` |
| CZH-652 | `23faf7bb` |
| CZH-653 | `07f0023f` |
| CZH-654 | `98aaa494` |

`CZH-655` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S10_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-69` acceptance).
