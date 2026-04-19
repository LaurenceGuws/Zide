# Core Engineer Entrypoint

Read in this exact order:

1. `docs/todo/core/implementation.md`
2. `docs/todo/core/JIRA_BOARD.md`
3. `docs/todo/core/CZH_B6_TICKETS.md`
4. `docs/AGENT_HANDOFF.md`
5. `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
6. `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md`
7. `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
8. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
9. `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

## Active Batch Rule

- Execute only the macro batch marked `in_progress` in
  `docs/todo/core/implementation.md`.
- If batch is `architect_review_pending`, stop and return a super-gate packet.

## Current Active Batch

- `CZH-B6` — **architect_review_pending** at **`CZH-GATE-60`** (layer freeze:
  **VT core FFI** = publication/query/redraw/events/metadata; **BYO-PTY host seam**
  = session/runtime/input/transport — distinct targets even when colocated under
  `ffi/`; **editor backend FFI**; **terminal surface** = shared GPU resource +
  Zide dirty/generation truth). Checkpoint (includes **`CZH-B6-corrective`**
  resubmit): `docs/todo/core/CZH_B6_CHECKPOINT.md`.

## Hard Rules

- Behavior freeze unless the batch explicitly permits behavior change.
- No stale debug/probe caller residue in tracked product code.
- Keep changes single-path (no fallback compatibility framing).
- No compatibility shims, migration leftovers, or preservation-only fallbacks.
- Audit file/module doc strings and important function doc strings in the
  touched layer set; if they lie about ownership, record it explicitly.
- Android lane is paused except blocker regressions.

## Engineer Cadence

- Target **5–10 validated commits** inside the batch before super-gate.
- Compile/test at each seam boundary; keep the tree buildable.
- Execute `CZH-601`..`CZH-610` sequentially from
  `docs/todo/core/CZH_B6_TICKETS.md`.
- Keep one ticket per commit.

## Validation Ladder

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- Android regression guard when seam-touching:
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`

## Required Response Format

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false`
