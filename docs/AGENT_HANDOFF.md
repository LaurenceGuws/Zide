## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- The only default product focus is Android terminal excellence until replaced
  by new authority.
- The repo goal is not generic renderer cleanup for its own sake.
- The repo goal is:
  - build the best Android terminal emulator we can
  - preserve Zide's resource-discipline and correctness values while doing it
  - use renderer/backend work only when it directly unblocks honest Android
    terminal implementation
- Current product sequencing:
  - mobile terminal first
  - extract reusable mobile-native fundamentals while building it
  - mobile editor second
  - integrated IDE mode only after terminal and editor each stand on their own
- Do not force a packaging decision yet:
  - one APK with multiple modes may be right later
  - separate mobile products sharing core code may also be right later
  - keep the architecture loose enough to support either
- Android host/bootstrap/device truth is now real enough that Android is no
  longer a hypothetical future pressure.
- Metal live validation is paused until explicitly reopened; do not let that
  stall active Android work.

### Current Direction

- The Android queue is now the default execution queue.
- Renderer work is still important, but only as a dependency lane for Android
  terminal adoption.
- Android platform code should stay disciplined, but it is allowed to own
  native mobile interaction surfaces where that produces the best UX.
- Do not force all mobile product behavior through the GPU texture path.
- Preferred execution style:
  - do the highest-leverage Android-unblocking work next
  - keep bootstrap-only Android proof work below `src/ui/renderer/` until the
    renderer queue explicitly opens that lane
  - do not reopen old renderer lanes unless they are the actual next blocker
    for Android terminal progress
  - do not drift into generic desktop/backend cleanup once the Android blocker
    is known

Execution discipline:

- default to the Android execution queue:
  - `docs/todo/android/implementation.md`
- use the renderer queue only when the Android queue says the next blocker is a
  renderer gate
- treat queue items as executable tickets, not vague themes
- if a task does not clearly map to the Android queue or a named Android
  blocker, it is probably drift

### Current State

- Android host/bootstrap truth is strong on the Note10:
  - lifecycle and surface identity are real
  - EGL surface recreation is proved for `replaced` and `retired -> acquired`
  - one EGL context and one minimal GLES texture survive those transitions on
    the current device path
- Android PTY baseline is also real:
  - disposable app-process-owned PTY lifetime is the baseline
  - service-owned PTY survival is validated as an optional product lane, not
    the default answer
- Android shell is now real on device:
  - `/system/bin/sh` runs through the repo terminal engine
  - product view is shell-first
  - IME overlay handling is live against the real shell path
  - app identity is now terminal-first:
    - package/application id: `dev.zide.terminal`
    - launcher activity: `ZideTerminalActivity`
  - repo path remains `android/bootstrap-bridge/` intentionally for now
- The current mobile product boundary is:
  - Zig owns terminal/runtime/core rendering primitives
  - Android code owns Android lifecycle/input/insets/overlay behavior
  - future mobile UX may live on both sides when that is the more honest fit
- The current active Android ticket is:
  - `AS-A3` in `docs/todo/android/implementation.md`
  - direct shell input ownership beyond the temporary composer
- The remaining shared-renderer blocker for first-class Android renderer work
  is still gate #5, but it is not the default lane right now.
- Gate #2 should be treated as closed for active work until Metal validation is
  explicitly reopened.

### Where To Look

- Active execution queue:
  - `docs/todo/android/implementation.md`
- Android authority:
  - `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
  - `app_architecture/platform/android/RENDER_BACKEND.md`
  - `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
  - `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- Renderer dependency authority:
  - `docs/todo/ui/renderer.md`
  - `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
  - `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

### Deferred Focuses

- VT maturity purity is deferred as the repo-wide default focus.
- When that lane is resumed, start from:
  - `docs/deferred/VT_MATURITY_FOCUS.md`
  - `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
  - `app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the
  relevant `app_architecture/` authority docs.
- Do not let older renderer-campaign framing outrank the Android queue while
  Android terminal excellence is the active goal.
- Do not work directly on `main`; treat it as merge-only and start active work
  on a branch from current `main`.
- Weaker agents must stay on feature branches and keep small reviewable
  checkpoint commits; `main` should only move when the lead accepts a validated
  chunk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
