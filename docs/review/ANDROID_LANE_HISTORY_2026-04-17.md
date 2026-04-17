# Android Lane History (Archived)

Date: 2026-04-17

This file archives the pre-refocus Android lane tracking notes that were
previously in active queue docs. It is historical evidence, not active queue
authority.

## Why Archived

- Active Android docs had grown into progress logs dense enough to slow
  execution.
- Refocus requires lean active docs centered on:
  - target shape,
  - current state,
  - milestone-gated execution.

## High-Level Archived Outcomes

- Adapter-depth reduction campaign landed with measurable callback/bridge tier
  deletions.
- `ZideActivity` callback and relay cleanup removed multiple pass-through seams.
- Widget callback tier collapsed (`host/ui/WidgetCallbacks.java` removed).
- `SelectionController` action-mode/clipboard seam simplification landed.
- `ShellInputView` complexity reduction wave landed.
- Debug view UI path was removed; diagnostics now use logging/scripted flows.
- Post-debug-view cleanup removed dead debug-mode coupling plumbing across
  runtime/surface/session seams.

## Source Of Historical Detail

- Git history for concrete incremental diffs and command-level validation.
- Android Java code in `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
  for current implementation state.
- Prior queue snapshots in commit history for milestone-by-milestone prose.

## Refocus Pointer

Active execution authority now lives in:

- `docs/todo/android/implementation.md`
- `docs/AGENT_HANDOFF.md`
- `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
