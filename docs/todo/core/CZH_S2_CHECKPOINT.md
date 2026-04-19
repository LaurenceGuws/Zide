# `CZH-S2` checkpoint — `CZH-GATE-61`

Date: 2026-04-19  
Sprint: `CZH-S2`  
Batch: `CZH-B7`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S2`
- Batch: `CZH-B7`
- Gate: `CZH-GATE-61` — **submitted for Architect review**
- Focus: first post-freeze implementation from accepted four-layer authority
  (VT core FFI, BYO-PTY seam, editor backend FFI, terminal surface contract).

## Scope summary

- **CZH-611:** `destroy` test sleep gated with `builtin.is_test` (no product-path
  sleep).
- **CZH-612:** module `//!` headers on terminal FFI/export + editor FFI files.
- **CZH-613:** `///` on key `core_api` / `host_api` exports for foreign hosts.
- **CZH-614:** snapshot-diff locals renamed (`granular_diff_ineligible`,
  `full_published_cells`); log message updated — **no semantic change**.
- **CZH-615:** this checkpoint + queue/board/handoff sync.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-611 | `8f351cf4` |
| CZH-612 | `2b76d32d` |
| CZH-613 | `08cbd94c` |
| CZH-614 | `dccf53eb` |

`CZH-615` is the commit that introduces this file and the `CZH-GATE-61` gate
state (`git log -1 -- docs/todo/core/CZH_S2_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-61` acceptance).
