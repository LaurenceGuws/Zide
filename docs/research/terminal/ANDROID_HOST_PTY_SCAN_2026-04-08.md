# Android Host + PTY Reference Scan (2026-04-08)

Purpose: capture the strongest Android-native host and terminal/PTTY reference
pressure before Zide starts Android event mapping or renderer bootstrap work.

This is research support for:

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `docs/todo/android/implementation.md`

It is not itself architecture authority.

## References Added Locally

These reference repos were added to the local `dev_references/` collection for
this lane:

- `dev_references/platform/android/ndk-samples`
- `dev_references/terminals/termux-app`
- `dev_references/terminals/android-terminal-emulator`

Why these three:

- `android/ndk-samples` is the official Android-native host/lifecycle pressure.
- `termux-app` is the modern Android terminal/PTTY reference.
- `Android-Terminal-Emulator` is older, but still useful as a stripped-down JNI
  PTY precedent.

## Host-Lifecycle Findings

The official NDK samples reinforce the same host rules already named in the
Android authority docs:

- `APP_CMD_INIT_WINDOW` and `APP_CMD_TERM_WINDOW` are first-class host events.
- `APP_CMD_WINDOW_RESIZED` and redraw-triggered commands are first-class host
  events.
- `ANativeWindow` is not permanent.

Concrete evidence:

- `dev_references/platform/android/ndk-samples/teapots/choreographer-30fps/src/main/cpp/ChoreographerNativeActivity.cpp`
  handles `APP_CMD_INIT_WINDOW` and `APP_CMD_TERM_WINDOW` directly in the main
  command switch.
- The same file explicitly warns that on some devices `ANativeWindow` is
  recreated when the app is resumed and reinitializes the rendering side when
  `app->window != gl_context_->GetANativeWindow()`.

Practical consequence for Zide:

- Android must be modeled as replaceable-surface truth, not persistent-window
  truth.
- The next Android host cut should wire:
  - lifecycle transitions
  - surface create/destroy/replace
  - resize
  - redraw-needed
- before any GLES backend bootstrap.

## PTY Findings

Native PTY-backed subprocesses are real on Android. This is not speculative.

Concrete evidence from `termux-app`:

- `dev_references/terminals/termux-app/terminal-emulator/src/main/jni/termux.c`
  opens `/dev/ptmx`, runs `grantpt` / `unlockpt` / `ptsname_r`, sets UTF-8 and
  winsize, then `fork`s, `setsid`s, `dup2`s the slave to stdio, and `execvp`s
  the command.
- `dev_references/terminals/termux-app/terminal-emulator/src/main/java/com/termux/terminal/JNI.java`
  exposes the PTY subprocess, resize, wait, and close primitives to Java.

Concrete evidence from `Android-Terminal-Emulator`:

- `dev_references/terminals/android-terminal-emulator/libtermexec/src/main/jni/process.cpp`
  uses the same core shape:
  - `/dev/ptmx`
  - `unlockpt`
  - `ptsname_r`
  - `fork`
  - `setsid`
  - `dup2`
  - `execv`

So the core conclusion is:

- Android PTY support is viable.
- JNI/native subprocess management is normal for Android terminals.

## The Real PTY Risk

The strongest risk is not “can Android do PTYs?” but “how stable is process
ownership under Android runtime policy?”

`termux-app`’s README explicitly warns that Android 12+ may kill phantom or
excessive-CPU processes, causing terminal sessions to die with `signal 9`
without user intent.

Practical consequence for Zide:

- PTY design on Android must account for process lifetime instability during
  backgrounding and long-running workloads.
- Root on the Note10 helps for experimentation, but product architecture should
  still treat process death as real platform pressure.
- The Android host/runtime seam should eventually answer:
  - what survives pause/resume
  - what survives stop/background
  - whether PTY state is host-owned, service-owned, or app-process-owned

## What To Do Next

Recommended immediate order:

1. finish Android host event mapping into `PlatformAppHost` and
   `PlatformRenderHost`
2. use the Note10 to validate lifecycle and surface truth on-device
3. only after that, define the Android PTY ownership model against real host
   behavior
4. only then decide whether Android rendering or Android PTY pressure is the
   stronger next blocker

## What Not To Do

Do not:

- start GLES bootstrap from PTY confidence alone
- assume `ANativeWindow` persistence
- assume PTY child processes are durable across Android background policy
- copy Termux packaging or app model wholesale
