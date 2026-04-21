# Handoff

Session entrypoint only. Keep this file short and current.

## Current Truth

- Default mode: **single operation** unless the user explicitly requests dual-agent operation.
- Mode policy: dual-agent mode is for sprint-scale batches; patch-sized cuts run in single operation mode.
- Product lane: **Core Zig freeze + hygiene**.
- Campaign: **Core Zig Stability/Hygiene** (`CZH`).
- Active phase sequence, in product order:
  1. product hot-path hygiene: baseline achieved in `CZH-S73` (audit + measurement; no executable cleanup targets remained)
  2. naming and module topology normalization for future widget extraction (completed in `CZH-S74`)
  3. Android progress consolidation into shared core seams (active)
  4. return to VT core correctness
- Current active batch: `CZH-B81` in `docs/todo/core/implementation.md`.
- Current sprint: `CZH-S76` in `docs/todo/core/CZH_S76_TICKETS.md`.
- Active board: `docs/todo/core/JIRA_BOARD.md`.
- Previous gate: `CZH-GATE-133` / `CZH-S74` closed and accepted; do not re-open naming/topology cuts without a new scoped ticket.

## Active Focus

`CZH-B81` continues Android-to-core consolidation by removing residual Android-specialized lifecycle ownership and thinning bridge code to platform-shell responsibilities.

## First Read Order

1. `docs/todo/core/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/core/CZH_S76_TICKETS.md`
3. `docs/todo/core/JIRA_BOARD.md`
4. `docs/todo/core/implementation.md`
5. `app_architecture/ENGINEERING.md`
6. `app_architecture/tools/STRUCTURED_LOGGING.md`
7. `app_architecture/platform/android/ANDROID_RENDER_THREAD_CONTRACT.md`
8. `app_architecture/terminal/VT_CORE_DESIGN.md`
9. relevant source files named by the active ticket

## Anti-Drift Rules

- No documentation-only implementation tickets in `CZH-S76` unless the ticket is explicitly labelled `doc-only` by Architect before execution.
- Each implementation ticket must change product code, tests, or both.
- Documentation updates are secondary evidence only: update the smallest owning doc after code/test movement.
- Do not optimize wording, trace matrices, or historical checkpoint structure while product-path hygiene remains open.
- If a ticket cannot name a concrete product path and a measurable cleanup result, stop and return to Architect.

## Validation Baseline

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- bounded terminal startup smoke when presentation/runtime paths are touched
- Android deploy/log smoke only when Android or shared Android-proving seams are touched

## Android Pause Contract

Android feature work remains paused except for blocker regressions and shared-seam validation required by the active core hygiene batch. Android evidence should be consolidated into shared core contracts only when the active phase reaches Android consolidation.
