# `CZH-S11` checkpoint — `CZH-GATE-70`

Date: 2026-04-19  
Sprint: `CZH-S11`  
Batch: `CZH-B16`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S11`
- Batch: `CZH-B16`
- Gate: `CZH-GATE-70` — **submitted for Architect review**
- Focus: `TerminalWidgetSurfaceState.presentationUpdateDelta` publication and
  clear-generation mismatch limbs consume existing
  `surface_contract.publicationGenerationDiffersFromLastSurfaceRender` and
  `clearGenerationDiffersFromLastSurfaceRenderClear`; no ABI or policy change.

## Scope summary

- **CZH-656:** audit — `presentationUpdateDelta` in `terminal_widget_surface_state.zig`.
- **CZH-657:** `surface_contract` docs bind delta limbs to existing helpers.
- **CZH-658:** `presentationUpdateDelta` routes `generation_changed` /
  `clear_generation_changed` through helpers.
- **CZH-659:** CZH-S11 test + `TERMINAL_SURFACE_CONTRACT.md` + queue landed note.
- **CZH-660:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-656 | `c3f5d301` |
| CZH-657 | `98d25d25` |
| CZH-658 | `7cdabc0d` |
| CZH-659 | `c46a4831` |

`CZH-660` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S11_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-70` acceptance).
