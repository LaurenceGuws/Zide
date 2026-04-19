# `CZH-S4` checkpoint — `CZH-GATE-63`

Date: 2026-04-19  
Sprint: `CZH-S4`  
Batch: `CZH-B9`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S4`
- Batch: `CZH-B9`
- Gate: `CZH-GATE-63` — **submitted for Architect review**
- Focus: optional BYO-PTY seam extracted out of `src/terminal/ffi/` to
  `src/terminal/byo_pty_host.zig`; bridge behavior and exported C symbols
  unchanged.

## Scope summary

- **CZH-621:** extraction touchpoint map in `implementation.md`.
- **CZH-622:** `git mv` to `src/terminal/byo_pty_host.zig`; `bridge.zig` imports
  `@import("../byo_pty_host.zig")`; no shim under `ffi/`.
- **CZH-623:** module docs / comments aligned with terminal-owned placement.
- **CZH-624:** `TERMINAL_SUBSYSTEM_LAYERS.md`, `VT_CORE_DESIGN.md`, queue
  inventory updated.
- **CZH-625:** this checkpoint + validation ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-621 | `088c075b` |
| CZH-622 | `d9a60ca4` |
| CZH-623 | `eafac101` |
| CZH-624 | `e8ed828f` |

`CZH-625` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S4_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-63` acceptance).
