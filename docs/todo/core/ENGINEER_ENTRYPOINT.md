# Core Engineer Entrypoint

Read in this exact order:

1. `docs/todo/core/implementation.md`
2. `docs/todo/core/JIRA_BOARD.md`
3. `docs/todo/core/CZH_S19_TICKETS.md`
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

- `CZH-B24` — **`in_progress`** toward **`CZH-GATE-78`** (sprint `CZH-S19`):
  surface observability vocabulary lock aligned to pipeline vs attachment vs generation terms
  (`docs/todo/core/CZH_S19_TICKETS.md`).

## Hard Rules

- Behavior freeze unless the batch explicitly permits behavior change.
- No stale debug/probe caller residue in tracked product code.
- Keep changes single-path (no fallback compatibility framing).
- No compatibility shims, migration leftovers, or preservation-only fallbacks.
- Audit file/module doc strings and important function doc strings in the
  touched layer set; if they lie about ownership, record it explicitly.
- Android lane is paused except blocker regressions.

## Engineer Cadence

- Target **8–14 validated commits** inside the batch before super-gate.
- Compile/test at each seam boundary; keep the tree buildable.
- Sprint `CZH-S19` tickets `CZH-731`..`CZH-740` are active; run to
  **`CZH-GATE-78`** unless blocked.
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
