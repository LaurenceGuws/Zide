# Core Engineer Entrypoint

Read in this exact order:

1. `docs/todo/core/implementation.md`
2. `docs/AGENT_HANDOFF.md`
3. `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
4. `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md`
5. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`

## Active Batch Rule

- Execute only the macro batch marked `in_progress` in
  `docs/todo/core/implementation.md`.
- If batch is `architect_review_pending`, stop and return a super-gate packet.

## Current Active Batch

- `CZH-B1` — **architect_review_pending** (freeze/stability baseline + drift
  watchlist + first recorded ladder run; see super-gate packet in
  `docs/todo/core/implementation.md`).

## Hard Rules

- Behavior freeze unless the batch explicitly permits behavior change.
- No stale debug/probe caller residue in tracked product code.
- Keep changes single-path (no fallback compatibility framing).
- Android lane is paused except blocker regressions.

## Engineer Cadence

- Target **5–10 validated commits** inside the batch before super-gate.
- Compile/test at each seam boundary; keep the tree buildable.

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
