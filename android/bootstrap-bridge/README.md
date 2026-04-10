# Zide Android Bootstrap Bridge

This is the active Android app host for Zide shell bring-up and Android-native
product work.

## Default Workflow

From repo root:

```sh
ops/android_bootstrap_bridge.sh deploy
```

That will:

1. build the Zig native bridge
2. build the Android debug APK with the Gradle wrapper
3. install it on the connected device
4. launch `ZideBootstrapActivity`

## Other Useful Commands

From repo root:

```sh
ops/android_bootstrap_bridge.sh doctor
ops/android_bootstrap_bridge.sh native
ops/android_bootstrap_bridge.sh apk
ops/android_bootstrap_bridge.sh install
ops/android_bootstrap_bridge.sh launch
ops/android_bootstrap_bridge.sh reinstall
ops/android_bootstrap_bridge.sh logcat
```

## Tooling Rules

- use env-driven SDK paths
- use the Gradle wrapper under `android/bootstrap-bridge/`
- do not track `.classpath`, `.project`, `.settings/`, or generated IDE output
- do not import `dev_references/` as active Java projects

If `ANDROID_HOME` / `ANDROID_SDK_ROOT` are unset, the helper script prefers:

1. `~/.local/share/zide-android-sdk`
2. `/opt/android-sdk`

## Neovim

Repo-root [`.nvim.lua`](/home/home/personal/zide/.nvim.lua) only does three
things:

- sets `ANDROID_HOME` / `ANDROID_SDK_ROOT` defaults when the local SDK exists
- exposes `:ZideAndroidBootstrapCd`
- exposes `:ZideAndroidEnv`

For Java work, prefer opening `android/bootstrap-bridge/` as the workspace
root.

## Current Product Shell

Current bootstrap product view is shell-first:

- transcript owns the screen
- terminal tap opens the IME path
- slim bottom assist strip provides phone keyboard helpers
- restart/debug live in a hidden left drawer

## Logs

```sh
ops/android_bootstrap_bridge.sh logcat
```
