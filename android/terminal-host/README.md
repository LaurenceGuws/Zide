# Zide Android Terminal Host

This is the active Android app host for Zide shell bring-up and Android-native
product work.

## Naming Note

- directory path is `android/terminal-host/`
- active app identity is terminal-first:
  - package/application id: `dev.zide.terminal`
  - launcher activity: `ZideTerminalActivity`

## Default Workflow

From repo root:

```sh
ops/android_terminal_host.py deploy
```

That will:

1. build the Zig native bridge
2. build the Android debug APK with the Gradle wrapper
3. install it on the connected device
4. launch `ZideTerminalActivity`

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
```

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

Current product view is shell-first:

- transcript owns the screen
- terminal tap opens the IME path
- slim bottom assist strip provides phone keyboard helpers
- restart/debug live in a hidden left drawer

## Logs

```sh
ops/android_terminal_host.py logcat
```
