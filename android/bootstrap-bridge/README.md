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

Optional shell bring-up smoke:

```sh
/opt/android-sdk/platform-tools/adb shell am start \
  -n dev.zide.androidbootstrap/.ZideBootstrapActivity \
  --ez debug_start_shell_once true
```

The bootstrap app now uses two screens:

- product view:
  - large live shell transcript
  - compact permanent controls: `IME`, `Restart`, `Debug`
  - IME targets the hidden `InputConnection` view that feeds the live shell
  - hidden probe `SurfaceView` kept only for bootstrap runtime/native checks
- debug view:
  - grouped GLES/runtime status
  - event log only

## Cursor / VS Code (Java language server)

The repo root `.vscode/settings.json` turns on **experimental Android Gradle
import** (`java.jdt.ls.androidSupport.enabled` = `on`). Without it, stable
VS Code / Cursor often shows “not on the classpath of project `app`” for every
file under `app/src/main/java` even though Gradle builds fine.

After pulling this, run **Java: Clean Java Language Server Workspace** (then
reload) once. Ensure `ANDROID_HOME` / `ANDROID_SDK_ROOT` are set in the
environment where you launch the editor so the importer can resolve the SDK.

## Neovim Workspace

For Java/LSP work, treat `android/bootstrap-bridge/` as the Android workspace
root, not the whole repo.

- repo root now ships a local [`.nvim.lua`](/home/home/personal/zide/.nvim.lua)
  that:
  - pins `ANDROID_HOME` / `ANDROID_SDK_ROOT` to
    `~/.local/share/zide-android-sdk` when present
  - exposes `:ZideAndroidBootstrapCd` to switch the local cwd to
    `android/bootstrap-bridge`
  - exposes `:ZideAndroidEnv` to print the active Android env seen by Neovim
- `dev_references/` is reference-only; do not treat those Gradle projects as
  active workspace imports
- generated Eclipse/JDT junk (`.project`, `.classpath`, `.settings/`) is now
  ignored repo-wide

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
  - `glesTextureCreates`
  - `glesTextureAlive`
  - `glesTextureUploads`
  - `glesTextureUpdates`
- Note10 lifecycle hardening now shows both replacement stories are real:
  - in-process `SurfaceView` recreation produced
    `transition=replaced ... glesBoundEpoch=2 glesContextCreates=1 glesSurfaceCreates=2 glesTextureCreates=1 glesTextureAlive=true glesTextureUploads=1 glesTextureUpdates=4`
  - later background-side retirement produced
    `transition=retired ... gles=surface-destroyed glesBoundEpoch=0 glesContextCreates=1 glesTextureCreates=1 glesTextureAlive=true glesTextureUploads=1 glesTextureUpdates=11`
  - the next foreground acquire produced
    `transition=acquired ... glesBoundEpoch=4 glesContextCreates=1 glesSurfaceCreates=3 glesTextureCreates=1 glesTextureAlive=true glesTextureUploads=1 glesTextureUpdates=12`
- that means the bootstrap EGL path now proves clean window-surface recreation
  for both `replaced` and `retired` then later `acquired`
- on the current Note10 path it also proves EGL context reuse across those
  transitions, rather than hidden context teardown/recreation
- and it now proves one minimal context-owned GLES texture survives across
  those same transitions too
- the upload/update counters now also show:
  - one initial upload at texture creation
  - repeated `glTexSubImage2D`-style updates on redraw and across surface
    replacement/retirement without hidden texture recreation on this device
- the first size-pressure probe now also shows:
  - a holder-driven resize can advance `glesTextureUploads` and
    `glesTextureResizes` with a clean shrink/restore pair:
    `1356x1104 -> 1356x552 -> 1356x1104`
  - that still keeps `glesContextCreates=1`, `glesSurfaceCreates=1`, and
    `glesTextureCreates=1`
  - Android still later emits one odd extra `surface.changed ... size=2675x0`
    on this debug path, so it is strong runtime-pressure evidence but not yet
    final product resize authority
- Android native entry is now real enough to move on to deeper host/runtime
  ownership questions rather than more bootstrap speculation
- the bootstrap lane now also contains the first real shell bring-up through
  the repo terminal engine:
  - `debug.shellStart status=started`
  - `manual.shellInput bytes=28`
  - transcript output showed:
    - `:/ $ printf 'android-shell-ok\n'`
    - `android-shell-ok`
