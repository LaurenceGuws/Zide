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

- terminal-host-owned
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

The first `AS-A1` cut is now implemented through the Android terminal host app
(`android/terminal-host/`).

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

`AS-A3` direct shell input

Purpose:

- move beyond the temporary line-composer path toward real key-by-key shell
  input on Android

## Previous Cut

`AS-A2` is met. See `docs/todo/android/implementation.md` for the full record.

## Current Product Result

`AS-A3` first cut is now implemented in the Android terminal host app
(`android/terminal-host/`).

Current input shape:

- each character typed in the IME composer is sent immediately to the PTY via a
  direct JNI → Zig → `zide_terminal_send_text` path
- the Java side now owns a real `InputConnection` surface with a minimal editor
  model instead of relying on `TextWatcher` tricks
- Enter sends `\n` directly
- Backspace sends `\x7f` directly
- Samsung text-editing arrows now work through the editor model and VT escape
  output
- stale file-indirection input has been removed from the active shell path
- input latency is now bounded by JNI call overhead instead of the 150ms poll
  interval

Architecture:

- `android_shell_session.zig` now exposes `sendText` and `sendCodepoint`
  directly on the active session handle
- `android_runtime_bridge.zig` exposes `sendShellCodepoint` for JNI
- `android_bridge_exports.zig` exports `nativeSendShellCodepointBridge`
- `ZideTerminalActivity` now exposes a dedicated IME surface with:
  - `onCheckIsTextEditor()`
  - `onCreateInputConnection(...)`
  - composing/commit/selection handling

What this proves:

- Android shell input is no longer limited to "type a whole line then send"
- the direct JNI path works for character-by-character terminal input
- the live Android `InputConnection` path is now the active input surface
- the minimal editor model is sufficient for current Samsung keyboard input and
  navigation behavior on the Note10

What this does not yet prove:

- the full physical-keyboard story
- special terminal keys beyond the currently proved editor-navigation subset
- the full long-term mobile terminal input surface design

Next likely follow-up:

1. extend the new Ctrl-modified key path beyond ASCII letters only if a real
   Android input device proves that narrower mapping insufficient
2. keep the current `InputConnection` model small and honest while terminal UX
   pressure is still local to shell mode
3. do not jump to a larger terminal-input surface unless the current model
   proves materially broken for the next product question

## Current `AS-A3` Hardening

The direct-input path now also accepts Ctrl-modified key events for `A` through
`Z` and sends the corresponding control bytes directly to the PTY. That keeps
the current Android input surface small while covering the first control-key
subset needed for real shell use such as `Ctrl+C` and `Ctrl+D`.

It now also covers the standard terminal-control punctuation subset:

- `Ctrl+[`
- `Ctrl+\`
- `Ctrl+]`
- `Ctrl+6`
- `Ctrl+/`
- `Ctrl+Space`
- `Ctrl+2`

And Android `KEYCODE_NUMPAD_ENTER` now routes to `\n` the same as normal
Enter.

Current Java ownership is also cleaner:

- `ZideTerminalActivity` is now orchestration only
- `ShellInputView` owns the editor model and `InputConnection`
- `ShellTranscriptController` owns transcript follow behavior
- `ShellSessionController` owns shell polling/transcript file reads
- `AndroidDebugFormatter` owns debug formatting

Current local-tooling support is also explicit:

- Neovim/JDTLS should import `android/terminal-host/` as the Java root
- `app/build.gradle` now declares the Eclipse/Buildship classpath support JDTLS
  was missing for this Android app module:
  - `src/main/java`
  - Android SDK `android.jar`
  - generated debug `R.jar`
- this is the sanctioned local Java-tooling path; do not reintroduce tracked
  `.classpath` / `.project` files as repo authority

Current product-shell layout is also now moving toward a mobile-native shape:

- the terminal transcript owns the screen without outer padding
- transcript tap opens the IME path directly (listeners on both the scroll host
  and inner transcript `TextView`, because touches usually hit the child)
- a slim bottom assist strip provides terminal helper input for phone-first use
- restart/debug controls now live behind a hidden left drawer instead of taking
  permanent vertical space
