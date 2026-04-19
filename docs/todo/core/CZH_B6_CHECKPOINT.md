# `CZH-B6` checkpoint — `CZH-GATE-60`

Date: 2026-04-19  
Sprint: `CZH-S1`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S1`
- Batch: `CZH-B6`
- Gate: `CZH-GATE-60` — **submitted for Architect review**
- Focus delivered: freeze the shared Zig split (VT core FFI, optional BYO-PTY host
  seam, editor backend FFI, terminal surface contract) with audits and a
  queued implementation sprint (`CZH-S2`).

## Scope summary

- **Four-layer messaging** aligned across queue, board, entrypoint, and tickets
  (`CZH-601`).
- **Terminal FFI file map** recorded in `TERMINAL_SUBSYSTEM_LAYERS.md`
  (`CZH-602`).
- **Editor FFI authority** tightened in `app_architecture/editor/FFI_DESIGN.md`
  (`CZH-603`).
- **Terminal surface contract** added: `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
  (`CZH-604`).
- **Cross-layer inventory + non-goals** in `docs/todo/core/implementation.md`
  (`CZH-605`).
- **Hard-rule audits** (probe/debug, compat/fallback, doc strings) recorded in
  `implementation.md` (`CZH-606`..`CZH-608`).
- **Next sprint** ticketed: `docs/todo/core/CZH_S2_TICKETS.md` (`CZH-609`).
- **This checkpoint** (`CZH-610`).

## #DONE

- `CZH-601` .. `CZH-610` (all sprint tickets; one commit each).

## #OUTSTANDING

- Architect acceptance of `CZH-GATE-60` (batch `CZH-B6`).
- `CZH-S2` (`CZH-611`..`CZH-615`) — **not** started; blocked on gate acceptance
  per board rules.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-601 | `3b772c77` |
| CZH-602 | `15c51c8d` |
| CZH-603 | `a43610d8` |
| CZH-604 | `04153fa3` |
| CZH-605 | `44ebe637` |
| CZH-606 | `a04c9bc4` |
| CZH-607 | `89cb2d5b` |
| CZH-608 | `015aa139` |
| CZH-609 | `15df5921` |

`CZH-610` is the commit that introduces this checkpoint and gate state (the tip
of the engineer branch at submission).

## VALIDATION (engineer run, 2026-04-19)

- `zig build` — PASS  
- `zig build test` — PASS  
- `zig build -Dmode=terminal` — PASS  
- `zig build -Dmode=editor` — PASS  
- `zig build test-config` — PASS  
- `zig build test-editor` — PASS  
- `zig build test-terminal-replay-all` — PASS  

Android Gradle guard — **SKIP** (lane paused; no Android seam touched).

## Authority pointers

- Board: `docs/todo/core/JIRA_BOARD.md`
- Sprint tickets (closed): `docs/todo/core/CZH_B6_TICKETS.md`
- Next sprint: `docs/todo/core/CZH_S2_TICKETS.md`
- Queue: `docs/todo/core/implementation.md`

## Blocked by Architect review needed

- **true** (for gate acceptance and moving `CZH-B6` from `architect_review_pending`
  to `accepted`).
