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
- Android host/bootstrap/device truth is now real enough that Android is no
  longer a hypothetical future pressure.
- Metal live validation is paused until explicitly reopened; do not let that
  stall active Android work.

### Current Direction

- The Android queue is now the default execution queue.
- Renderer work is still important, but only as a dependency lane for Android
  terminal adoption.
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
- The remaining shared-renderer blocker for first-class Android renderer work
  is gate #5, not gate #4.
- Gate #2 should be treated as closed for active work until Metal validation is
  explicitly reopened.
- The current repo question is:
  - what is the next highest-leverage move toward a first-class Android
    terminal
  - and is that move still bootstrap-owned Android work or the next honest
    gate-5 renderer cut
- Do not let the older renderer-campaign framing hide that product goal.

### Where To Look

- Active execution queue:
  - `docs/todo/android/implementation.md`
- Android authority:
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
