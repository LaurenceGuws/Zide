# CZH-S37 Checkpoint — Callback Surface Reduction + Boundary Hardening

**Sprint:** CZH-S37  
**Batch:** CZH-B42  
**Gate:** CZH-GATE-96  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

All 10 tickets executed in order. No behavior changes. No host ABI/C export changes. No fallback branches introduced.

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-911 | `c22d7747` | Boundary audit + reduction map |
| CZH-912 | `4d01c1b2` | Authority tightening (doc-only) |
| CZH-913 | `b1abc3cb` | Refresh callback surface reduction (remove implicit ctx field requirement) |
| CZH-914 | `603444c8` | Reuse callback surface reduction (struct-based eligibility inputs) |
| CZH-915 | `b7e87f3b` | Direct-present callback surface reduction (struct-based eligibility inputs) |
| CZH-916 | `7c8b8584` | Widget facade contraction (stop threading redundant `view_cells_len`) |
| CZH-917 | `0aced96d` | Helper-level invariants (lock reduced contracts) |
| CZH-918 | `28971b86` | Integration boundary invariants (type identity locked at widget facade) |
| CZH-919 | `d1ab3497` | Hygiene sweep (remove ticket lineage from touched source comment) |
| CZH-920 | (this commit) | Validation packet + gate handoff |

## Validation

- `zig build`: PASS
- `zig build test`: PASS
- `zig build -Dmode=terminal`: PASS
- `zig build -Dmode=editor`: PASS
- `timeout 3s zig build run -- --mode terminal`: PASS (bounded startup smoke)
- Android regression guard (connected device `RF8M74JDWEK`): PASS
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

## Key Changes

### Refresh surface hardening

- `runTerminalPresentableRefreshExecution(...)` no longer requires an implicit `ctx.result` field.
- Widget refresh update ctx no longer carries unused fields for host wiring.

### Eligibility contract reductions

- Reuse eligibility now takes a single `ReuseEligibilityInput` struct.
- Direct-present eligibility now takes a single `DirectPresentEligibilityInput` struct.

### Facade contraction

- Widget presentation runtime derives `view_cells_len` from `terminal_view.cells.len` instead of threading it through multiple signatures.

### Invariants and integration locks

- Added helper-level invariant test to prevent regressions reintroducing hidden ctx-shape requirements.
- Widget facade re-exports reduced-contract input structs; integration tests lock type identity.

## Board / Gate Notes

- Per `docs/todo/core/JIRA_BOARD.md` rules, moving tickets into `review_gate`/`done` is Architect-owned.
- This checkpoint is the engineer gate packet for `CZH-GATE-96` review.

## Files Touched (S37)

- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/renderer/renderer_presentable_host.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/CZH_911_BOUNDARY_AUDIT_REDUCTION_MAP.md`
- `docs/todo/core/CZH_891_CALLBACK_EXTRACTION_AUDIT.md`
- `docs/todo/core/CZH_892_CALLBACK_AUTHORITY.md`
- `docs/todo/core/implementation.md`

