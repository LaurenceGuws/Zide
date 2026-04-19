# Core Engineer Entrypoint

Read in this exact order:

1. `docs/todo/core/implementation.md`
2. `docs/todo/core/JIRA_BOARD.md`
3. `docs/todo/core/CZH_S5_TICKETS.md`
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

- `CZH-B10` — **`architect_review_pending`** at **`CZH-GATE-64`** (sprint `CZH-S5`):
  FFI/export doc drift closed in tree; **stop** for Architect gate. Packet:
  `docs/todo/core/CZH_S5_CHECKPOINT.md`.

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
- Sprint `CZH-S5` tickets `CZH-626`..`CZH-630` are complete at **`CZH-GATE-64`**
  unless Architect reopens scope.
- Keep one ticket per commit (historical sprint rule).

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
