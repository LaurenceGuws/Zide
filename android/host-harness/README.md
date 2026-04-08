# Zide Android Host Harness

Purpose: provide a tiny repo-owned Android app that exercises native-host
pressure before any Android renderer backend bootstrap.

This app is intentionally:

- host-focused
- Java-only
- no SDL
- no NDK
- no GLES/Vulkan backend bootstrap

Use it to validate:

- `Activity` lifecycle ordering
- `SurfaceView` create/change/destroy/redraw callbacks
- window focus changes
- IME show/hide and text-input focus behavior

This harness is not Zide-on-Android yet. It is a host-truth probe.

## Build

From repo root:

```sh
ANDROID_HOME="$HOME/.local/share/zide-android-sdk" \
ANDROID_SDK_ROOT="$HOME/.local/share/zide-android-sdk" \
gradle -p android/host-harness :app:assembleDebug
```

APK output:

`android/host-harness/app/build/outputs/apk/debug/app-debug.apk`

## Install

```sh
/opt/android-sdk/platform-tools/adb install -r android/host-harness/app/build/outputs/apk/debug/app-debug.apk
```

If `/opt/android-sdk` is root-owned or missing the required platform/build-tools
packages, a user-writable clone works fine. This branch was validated with:

`$HOME/.local/share/zide-android-sdk`

## What To Test

1. launch app and observe lifecycle + surface callback log
2. lock/unlock device and background/foreground the app
3. rotate device
4. tap the IME field and use the show/hide buttons
5. watch whether focus, text-input, and surface callbacks occur in stable,
   explainable order
