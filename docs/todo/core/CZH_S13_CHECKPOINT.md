# `CZH-S13` checkpoint — `CZH-GATE-72`

Date: 2026-04-19  
Sprint: `CZH-S13`  
Batch: `CZH-B18`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S13`
- Batch: `CZH-B18`
- Gate: `CZH-GATE-72` — **submitted for Architect review**
- Focus: VT FFI `redraw_state` / `needs_redraw` / `present_ack` seam named
  `ffiRedrawStateFill`, `ffiNeedsRedrawU8`, `ffiPresentAckGenerationAdmissible` in
  `surface_contract`; `core_api` routes through them; no ABI or behavior drift.

## Scope summary

- **CZH-671:** audit + hygiene scope.
- **CZH-672** / **CZH-674:** FFI redraw and present-ack wrappers.
- **CZH-673** / **CZH-675:** `core_api` wiring.
- **CZH-676:** doc alignment.
- **CZH-677** / **CZH-678:** invariant tests (`surface_contract`, `core_api`).
- **CZH-679:** probe sweep note + `TERMINAL_SURFACE_CONTRACT.md` sync.
- **CZH-680:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-671 | `6106f474` |
| CZH-672 | `6f7377e3` |
| CZH-673 | `d3d8285e` |
| CZH-674 | `f0589eef` |
| CZH-675 | `37f1a07d` |
| CZH-676 | `addc96fd` |
| CZH-677 | `c716a112` |
| CZH-678 | `6e1563f3` |
| CZH-679 | `e8bb08c9` |

`CZH-680` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S13_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-72` acceptance).
