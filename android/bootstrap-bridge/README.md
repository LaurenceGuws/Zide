# Zide Android Bootstrap Bridge

Purpose: provide the first repo-owned Android bootstrap path for the real Zig
runtime lane.

This is intentionally:

- Android app + native Zig bridge
- lifecycle/surface focused
- not a renderer backend bootstrap
- not PTY/runtime design

Use it to prove:

- the repo can build a native Android Zig library
- an Android app can load that library
- lifecycle and surface callbacks can cross into repo-owned native code

## Build Native Library

From repo root:

```sh
ANDROID_HOME="$HOME/.local/share/zide-android-sdk" \
ANDROID_SDK_ROOT="$HOME/.local/share/zide-android-sdk" \
ops/android_build_bootstrap_bridge.sh
```

This writes:

`android/bootstrap-bridge/app/src/main/jniLibs/arm64-v8a/libzide_android_bridge.so`

The bridge build expects NDK `27.1.12297006` in the selected SDK root.
It links `libandroid` because the bridge now uses
`ANativeWindow_fromSurface(...)` and `ANativeWindow_release(...)`.

## Build APK

```sh
ANDROID_HOME="$HOME/.local/share/zide-android-sdk" \
ANDROID_SDK_ROOT="$HOME/.local/share/zide-android-sdk" \
gradle -p android/bootstrap-bridge :app:assembleDebug
```

APK output:

`android/bootstrap-bridge/app/build/outputs/apk/debug/app-debug.apk`

## Install

```sh
/opt/android-sdk/platform-tools/adb install -r android/bootstrap-bridge/app/build/outputs/apk/debug/app-debug.apk
```

## Launch

```sh
/opt/android-sdk/platform-tools/adb shell am start -n dev.zide.androidbootstrap/.ZideBootstrapActivity
```

Optional in-process surface recreation probe:

```sh
/opt/android-sdk/platform-tools/adb shell am start \
  -n dev.zide.androidbootstrap/.ZideBootstrapActivity \
  --ez debug_recreate_surface_once true
```

## Useful Logs

```sh
/opt/android-sdk/platform-tools/adb logcat -c
# reproduce lifecycle/surface behavior
/opt/android-sdk/platform-tools/adb logcat -d -s ZideAndroidBootstrap:I
```

## Current Note10 Read

Current successful bootstrap run:

- `activity.onCreate nativeLoaded=true`
- `native.onCreate seq=1`
- `native.onStart seq=2`
- `native.onResume seq=3`
- `native.surfaceAvailable seq=4 token=0x... epoch=1 transition=acquired`
- `native.surfaceAvailable seq=5 token=0x... epoch=1 transition=unchanged`
- `native.onWindowFocus seq=6`
- forced rotation also stayed on the same surface identity:
  - `native.surfaceAvailable seq=7 token=0x... epoch=1 transition=unchanged`
  - `native.surfaceAvailable seq=8 token=0x... epoch=1 transition=unchanged`
  - `native.surfaceAvailable seq=9 token=0x... epoch=1 transition=unchanged`
- HOME/background also confirms:
  - `native.onPause seq=10`
  - `native.surfaceAvailable seq=11 token=0x... epoch=1 transition=unchanged`
  - `native.surfaceAvailable seq=12 token=0x... epoch=1 transition=unchanged`
  - `native.onWindowFocus seq=13`
  - `native.surfaceDestroyed seq=14 token=0x0 epoch=2 transition=retired`
  - `native.onStop seq=15`
- bringing the task back to foreground then produced:
  - a fresh `native.surfaceAvailable ... epoch=3 transition=acquired`
  - even though the raw token value could recur, the epoch still advanced

That proves:

- the APK loads a repo-built Zig native library
- Java lifecycle/surface callbacks are crossing into repo-owned Zig code
- those callbacks now route through shared Android host semantics rather than a
  private bridge-only lifecycle model
- the bridge can now surface explicit surface identity transitions:
  `acquired`, `unchanged`, and `retired`
- on the current Note10 path, forced rotation and pause-side geometry churn are
  still `transition=unchanged`, so large size changes do not imply replacement
- on this same path, foreground return after `retired` becomes a fresh
  `acquired`, so raw token reuse is not sufficient to define identity
- an explicit in-activity `SurfaceView` recreation probe can also produce a
  true `transition=replaced`
- Android native entry is now real enough to move on to deeper host/runtime
  ownership questions rather than more bootstrap speculation
