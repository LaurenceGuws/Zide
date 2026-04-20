# Core Engineer Entrypoint

Read in this exact order:

1. `docs/todo/core/implementation.md`
2. `docs/todo/core/JIRA_BOARD.md`
3. `docs/todo/core/CZH_S60_TICKETS.md`
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

- `CZH-B68` — **`in_progress`** toward **`CZH-GATE-122`** (sprint `CZH-S63`):
  governance runtime-to-test binding tightening: make enforcement claims explicitly verifiable through compile/test guards.
  Ticket source: `docs/todo/core/CZH_S63_TICKETS.md`.

## Hard Rules

- Behavior freeze unless the batch explicitly permits behavior change.
- Startup/runtime regressions are correctness fixes; repair them directly and
  document the behavior impact.
- No stale debug/probe caller residue in tracked product code.
- Keep changes single-path (no fallback compatibility framing).
- No compatibility shims, migration leftovers, or preservation-only fallbacks.
- Current FFI/caller placement is not frozen; callers may move if the mature
  ownership split requires it.
- Audit file/module doc strings and important function doc strings in the
  touched layer set; if they lie about ownership, record it explicitly.
- Source comments must not carry ticket/sprint/progress history. Keep them to
  current ownership, invariants, and constraints.
- Android lane is paused except blocker regressions; the connected device
  `RF8M74JDWEK` is available for this checkpoint.
- Windows/macOS validation is non-blocking unless their platform code is touched.

## Engineer Cadence

- Target **8–14 validated commits** inside the batch before super-gate.
- Compile/test at each seam boundary; keep the tree buildable.
- Sprint `CZH-S63` tickets `CZH-1149`..`CZH-1156` are active; run to
  **`CZH-GATE-122`** unless blocked.
- Keep one ticket per commit (historical sprint rule).

## Validation Ladder

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- Bounded Linux GUI startup smoke for terminal mode: launch, verify init gets
  past the targeted assertion failure, then terminate; do not leave a GUI open
  as a test process.
- Android regression guard when seam-touching:
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

## Required Response Format

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false`
