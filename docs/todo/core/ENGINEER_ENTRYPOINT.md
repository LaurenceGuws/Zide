# Core Engineer Entrypoint

Use this entrypoint only when the user explicitly requests dual-agent mode for a sprint-scale batch. Patch-sized cuts should run in single operation mode.

Read in this exact order:

1. `docs/todo/core/CZH_S76_TICKETS.md`
2. `docs/todo/core/JIRA_BOARD.md`
3. `docs/todo/core/implementation.md`
4. `docs/AGENT_HANDOFF.md`
5. `app_architecture/ENGINEERING.md`
6. `app_architecture/tools/STRUCTURED_LOGGING.md`
7. `app_architecture/platform/android/ANDROID_RENDER_THREAD_CONTRACT.md`
8. source files named by the active ticket

## Current Active Batch

- `CZH-B81` — `in_progress` toward `CZH-GATE-135`
- Sprint: `CZH-S76`
- Ticket source: `docs/todo/core/CZH_S76_TICKETS.md`
- Focus: Android-to-core consolidation phase 2 (remove residual platform ownership residue and thin bridge responsibilities).

## Hard Rules

- Code/test movement is mandatory for every ticket except an explicitly labelled `doc-only` ticket.
- Do not create documentation-only commits for implementation tickets.
- No behavior or ABI changes unless the ticket explicitly identifies a correctness bug.
- No compatibility shims, fallback branches, or preservation-only seams.
- Classify every touched logging/probe/counter/capture artifact as correctness contract, operator telemetry, or probe/debug capture; remove anything that does not fit.
- Product hot paths must not update debug capture state or execute investigation logging by default.
- Tests and temporary inline debugging may use debug helpers; real app paths may not retain investigation scaffolding.
- Keep naming/topology changes scoped to ticket boundaries; no broad folder reshuffle.

## Engineer Cadence

- Execute tickets in board order.
- One ticket per commit unless Architect explicitly approves otherwise before execution.
- Keep commits code-first and reviewable.
- If the next ticket appears to require mostly markdown, stop and ask Architect for re-scope.

## Validation Ladder

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- Bounded terminal startup smoke when presentation/runtime paths are touched.
- Android deploy/log smoke only when Android or Android-proving shared seams are touched.

## Required Response Format

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Architect review needed: true|false`
