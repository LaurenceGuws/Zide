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
- `native.surfaceAvailable seq=4`
- `native.onWindowFocus seq=5`

That proves:

- the APK loads a repo-built Zig native library
- Java lifecycle/surface callbacks are crossing into repo-owned Zig code
- Android native entry is now real enough to move on to shared-host
  integration rather than more bootstrap speculation
