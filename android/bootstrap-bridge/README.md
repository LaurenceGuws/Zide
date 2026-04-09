# Zide Android Bootstrap Bridge

Purpose: provide the first repo-owned Android bootstrap path for the real Zig
runtime lane.

This is intentionally:

- Android app + native Zig bridge
- lifecycle/surface focused
- not a renderer backend bootstrap
- not terminal product integration

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
It now also links `libEGL` and `libGLESv2` for the bootstrap-owned EGL probe.

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

Optional PTY lifetime probe:

```sh
/opt/android-sdk/platform-tools/adb shell am start \
  -n dev.zide.androidbootstrap/.ZideBootstrapActivity \
  --ez debug_start_pty_probe_once true
```

Optional foreground-service PTY probe:

```sh
/opt/android-sdk/platform-tools/adb shell am start \
  -n dev.zide.androidbootstrap/.ZideBootstrapActivity \
  --ez debug_start_service_pty_probe_once true
```

Optional foreground-service PTY probe stop:

```sh
/opt/android-sdk/platform-tools/adb shell am start \
  -n dev.zide.androidbootstrap/.ZideBootstrapActivity \
  --ez debug_stop_service_pty_probe_once true
```

The service is intentionally internal-only (`exported=false`), so the activity
extras are the supported debug entrypoints for this probe.

The app also now exposes on-device PTY controls:

- `Start PTY`
- `Stop PTY`
- `Restart PTY`
- `Refresh PTY`

And a live PTY status panel showing:

- alive vs dead
- child pid
- last start status
- heartbeat count
- last heartbeat line
- log path

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
- the PTY lifetime probe also now shows:
  - app-process-owned PTY survives `HOME` / pause / stop briefly on the
    Note10
  - app-process-owned PTY does not survive `am force-stop`
- the bootstrap app can now observe that disposable baseline directly on
  device instead of relying on adb-only file checks
- the bootstrap app now also logs PTY lifecycle snapshots at:
  - `activity.onStart.pty`
  - `activity.onResume.pty`
  - `activity.onPause.pty`
  - `activity.onStop.pty`
- the bootstrap lane now also contains the minimal foreground-service PTY
  probe needed for the separate service-survival decision lane
- that probe now validates on the Note10:
  - `debug.servicePtyProbeStartIssued`
  - `service.start pid=... alive=true status=started`
  - later `debug.servicePtyProbeStopIssued`
  - `service.stop pid=-1 alive=false`
- the bootstrap lane now also contains the first Android EGL/GLES binding
  proof, with current Note10 logs showing:
  - `native.surfaceAvailable ... gles=drawn`
  - `native.surfaceRedrawNeeded ... gles=drawn`
  - later same-surface geometry churn still reporting
    `transition=unchanged gles=drawn`
- the EGL probe now also exposes:
  - `glesSwaps`
  - `glesBoundEpoch`
  - `glesContextCreates`
  - `glesSurfaceCreates`
- Note10 lifecycle hardening now shows both replacement stories are real:
  - in-process `SurfaceView` recreation produced
    `transition=replaced ... glesBoundEpoch=2 glesContextCreates=1 glesSurfaceCreates=2`
  - later background-side retirement produced
    `transition=retired ... gles=surface-destroyed glesBoundEpoch=0 glesContextCreates=1`
  - the next foreground acquire produced
    `transition=acquired ... glesBoundEpoch=4 glesContextCreates=1 glesSurfaceCreates=3`
- that means the bootstrap EGL path now proves clean window-surface recreation
  for both `replaced` and `retired` then later `acquired`
- on the current Note10 path it also proves EGL context reuse across those
  transitions, rather than hidden context teardown/recreation
- Android native entry is now real enough to move on to deeper host/runtime
  ownership questions rather than more bootstrap speculation
