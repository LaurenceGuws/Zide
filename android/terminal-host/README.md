# Zide Android Terminal Host

This is the active Android app host for Zide shell-readiness baseline follow-on
and Android-native product work.

## Naming Note

- directory path is `android/terminal-host/`
- active app identity is terminal-first:
  - package/application id: `uk.laurencegouws.zide`
  - launcher activity: `ZideActivity`

## Default Workflow

From repo root:

```sh
ops/android_terminal_host.py deploy
ops/android_terminal_host.py --variant profile deploy
ops/android_terminal_host.py --variant release deploy
```

That will:

1. build the Zig native bridge
2. build the Android debug APK with the Gradle wrapper
3. install it on the connected device
4. launch `ZideActivity`

Variant policy:

- `debug`: default development lane
- `profile`: local performance-testing build, `ReleaseFast` Zig optimize, Android
  `profile` build type, debug signing, debuggable true
- `release`: local release-shape build, `ReleaseFast` Zig optimize, Android
  `release` build type, debug signing for local install

## Other Useful Commands

From repo root:

```sh
ops/android_terminal_host.py doctor
ops/android_terminal_host.py native
ops/android_terminal_host.py apk
ops/android_terminal_host.py install
ops/android_terminal_host.py launch
ops/android_terminal_host.py reinstall
ops/android_terminal_host.py logcat
ops/android_terminal_host.py userland-state
ops/android_terminal_host.py userland-smoke-baseline
ops/android_terminal_host.py userland-nvim-manual-check
```

Product gesture ownership:

- single tap on the terminal surface opens the IME
- pinch on the terminal surface adjusts shared renderer zoom / terminal font
  size
- keyboard defaults stay unchanged
- long press is intentionally unassigned until it has one clear product owner

Current performance-testing entrypoint:

```sh
ops/android_terminal_host.py --variant profile deploy
```

That uses:

- Android `profile` build type
- Zig `ReleaseFast` for the native bridge
- debug signing for local install

## Tooling Rules

- use env-driven SDK paths
- use the Gradle wrapper under `android/terminal-host/`
- do not track `.classpath`, `.project`, `.settings/`, or generated IDE output
- do not import `dev_references/` as active Java projects

If `ANDROID_HOME` / `ANDROID_SDK_ROOT` are unset, the helper script prefers:

1. `~/.local/share/zide-android-sdk`
2. `/opt/android-sdk`

## Neovim

Repo-root [`.nvim.lua`](/home/home/personal/zide/.nvim.lua) only does three
things:

- sets `ANDROID_HOME` / `ANDROID_SDK_ROOT` defaults when the local SDK exists
- exposes `:ZideAndroidHostCd`
- exposes `:ZideAndroidEnv`

For Java work, prefer opening `android/terminal-host/` as the workspace
root.

Current JDTLS rule:

- treat `android/terminal-host/` as the Java/Gradle root
- do not point JDTLS at the repo root
- if JDTLS gets stuck on stale Android metadata, clear the workspace and reopen:

```sh
rm -rf ~/.local/share/nvim/site/java/workspace-root/terminal-host-*
```

Repo-side support for that workflow now lives in Gradle:

- `app/build.gradle` declares Eclipse/Buildship source roots for JDTLS
- it also adds the Android SDK `android.jar` and generated debug `R.jar` to the
  Eclipse classpath model
- this keeps Android Java resolution working in Neovim without tracked
  `.classpath` / `.project` files

## Current Product Shell

Current product view is shared-renderer-only:

- the Zig shared renderer owns visible shell output
- terminal tap opens the IME path
- slim bottom assist strip provides phone keyboard helpers
- restart/debug live in a hidden left drawer
- no Java transcript fallback remains on the product path

## Current Neovim Check

Use:

```sh
ops/android_terminal_host.py userland-nvim-manual-check
```

That prints the current `AN-A1` manual validation flow and the exact behaviors
that should count as concrete Android blockers.

## Logs

```sh
ops/android_terminal_host.py logcat
```
