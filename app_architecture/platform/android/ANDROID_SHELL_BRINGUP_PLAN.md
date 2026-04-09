# Android Shell Bring-Up Plan

Purpose: define the first honest Android shell lane after host/bootstrap and
PTY baseline proof, without pretending shared Android renderer work is open.

Owner docs:

- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `docs/todo/android/implementation.md`

## Why This Is Next

The current Android truth is already strong enough in the two prerequisite
areas:

- host/bootstrap/runtime truth is real on the Note10
- disposable app-process-owned PTY lifetime is the current Android baseline

That means the next highest-leverage Android step is no longer another probe.

It is:

- start a real shell process on device
- route input into it
- route output back through the repo's real terminal engine
- prove that loop without waiting for shared Android renderer adoption

## Decision

The first Android shell cut should be:

- bootstrap-bridge-owned
- terminal-FFI-backed
- PTY-backed through the real terminal engine
- transcript-oriented, not renderer-oriented

It should not be:

- a partial Android renderer backend
- terminal widget integration in `src/ui/renderer/`
- IME/prompt-avoidance polish
- a service-owned session architecture decision

## Required Questions

This lane must answer:

1. Can the bootstrap app start `/system/bin/sh` through the repo's real
   terminal FFI path on Android?
2. Can the bootstrap app send text/newline input into that shell?
3. Can the bootstrap app poll/snapshot the resulting terminal state and expose
   visible output on device?
4. Does that loop work honestly enough that later IME/prompt handling can be
   solved against a live terminal instead of a probe surface?

## Scope

`AS-A1` first shell transcript loop

Purpose:

- prove the smallest real Android shell loop against the repo terminal engine

Acceptance:

- one bootstrap-owned shell session manager exists under `src/platform/`
- it creates one `ZideTerminalHandle`
- it resizes the session to a fixed bootstrap size
- it starts `/system/bin/sh`
- it supports sending plain text plus newline
- it polls and snapshots terminal output into a plain transcript string
- the bootstrap app can:
  - start or restart the shell
  - send one line of input
  - display live transcript output
- local validation stays green
- device proof shows real shell I/O on the Note10

Do not do:

- no shared renderer integration
- no terminal cell rendering on the GLES surface
- no scrollback/selection polish
- no IME avoidance/prompt visibility policy yet
- no service-owned shell/session survival design

## Stop Marker

Stop `AS-A1` when:

- a real shell is running on device through the repo terminal engine
- shell input and output are both visible and repeatable
- the Android queue can honestly say shell bring-up is no longer the blocker
- the next Android lane can then become prompt/IME/viewport behavior against a
  live shell, or renderer adoption if that is clearly the stronger blocker

## Current Device Result

The first `AS-A1` cut is now implemented through the bootstrap bridge.

Current shape:

- `src/platform/android_shell_session.zig` owns one bootstrap-only shell
  session manager
- it creates one `ZideTerminalHandle`
- it resizes to a fixed bootstrap terminal size
- it starts `/system/bin/sh`
- it consumes pending input from a bootstrap-owned input file
- it snapshots terminal state back into a plain transcript file
- the bootstrap app exposes:
  - product view:
    - live shell transcript
    - shell input/send
    - IME toggle against the real shell input
  - debug view:
    - diagnostics only

Observed on the Note10:

- the shell start path now logs:
  - `debug.shellStart status=started`
- the first automated command injection logs:
  - `manual.shellInput bytes=28`
- the resulting transcript shows real shell I/O:
  - `:/ $ printf 'android-shell-ok\n'`
  - `android-shell-ok`

This proves:

- Android shell bring-up is real through the repo terminal engine
- Android input and output can now be exercised against a live shell instead
  of a PTY heartbeat probe
- the next Android product question should be prompt/viewport/IME behavior
  against that live shell, not more bootstrap speculation

## Next Cut

`AS-A2` live-shell viewport and prompt behavior

Purpose:

- move the live shell interaction onto the product screen so prompt visibility,
  input focus, and IME behavior are exercised where they matter

Acceptance:

- product view owns the live shell transcript and input controls
- IME toggle targets the real shell input field
- transcript auto-follows live output so the prompt stays visible by default
- debug view returns to diagnostics only

Do not do:

- no shared renderer integration
- no cell-accurate terminal rendering
- no selection/scrollback polish beyond keeping live output visible

## Current Product Result

`AS-A2` is now implemented in the bootstrap bridge.

Current product shape on the Note10:

- product view is shell-first:
  - one large live transcript area
  - one compact control row: `IME`, `Restart`, `Debug`
  - temporary floating input composer only while IME is active
- IME handling now follows Android overlay truth instead of assuming resize:
  - product view applies bottom insets
  - the keyboard no longer covers the prompt/input row by default
  - landscape fullscreen extract mode is disabled for the temporary composer
- transcript behavior is now product-usable:
  - dead trailing blank rows are trimmed after geometry change
  - manual upward scroll detaches auto-follow until the view returns near the
    bottom
  - IME-active prompt entry still forces follow to the bottom

This proves:

- the live shell loop is no longer stuck behind a debug-only screen
- prompt/viewport/IME behavior is now being solved against the real Android
  shell loop
- the next Android shell question should move from layout/bootstrap behavior to
  richer shell interaction, most likely direct key-by-key PTY input
