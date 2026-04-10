#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$ROOT/android/bootstrap-bridge"
APK_PATH="$BRIDGE_DIR/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE_NAME="dev.zide.androidbootstrap"
ACTIVITY_NAME="$PACKAGE_NAME/.ZideBootstrapActivity"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "${SDK_ROOT}" ]]; then
  if [[ -d "$HOME/.local/share/zide-android-sdk" ]]; then
    SDK_ROOT="$HOME/.local/share/zide-android-sdk"
  elif [[ -d "/opt/android-sdk" ]]; then
    SDK_ROOT="/opt/android-sdk"
  else
    echo "missing Android SDK: set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
    exit 1
  fi
fi

export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"

ADB="$SDK_ROOT/platform-tools/adb"
GRADLEW="$BRIDGE_DIR/gradlew"

if [[ ! -x "$GRADLEW" ]]; then
  echo "missing Gradle wrapper: $GRADLEW" >&2
  exit 1
fi

if [[ ! -x "$ADB" ]]; then
  echo "missing adb: $ADB" >&2
  exit 1
fi

cmd="${1:-help}"

build_native() {
  "$ROOT/ops/android_build_bootstrap_bridge.sh"
}

build_apk() {
  (cd "$BRIDGE_DIR" && ./gradlew :app:assembleDebug)
}

install_apk() {
  "$ADB" install -r "$APK_PATH"
}

launch_app() {
  "$ADB" shell am start -n "$ACTIVITY_NAME"
}

case "$cmd" in
  native)
    build_native
    ;;
  apk)
    build_apk
    ;;
  install)
    install_apk
    ;;
  launch)
    launch_app
    ;;
  deploy)
    build_native
    build_apk
    install_apk
    launch_app
    ;;
  clean)
    (cd "$BRIDGE_DIR" && ./gradlew clean)
    ;;
  reinstall)
    "$ADB" uninstall "$PACKAGE_NAME" || true
    install_apk
    launch_app
    ;;
  logcat)
    "$ADB" logcat -d -s ZideAndroidBootstrap:I AndroidRuntime:E '*:S'
    ;;
  doctor)
    echo "ROOT=$ROOT"
    echo "BRIDGE_DIR=$BRIDGE_DIR"
    echo "ANDROID_HOME=$ANDROID_HOME"
    echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
    echo "ADB=$ADB"
    echo "GRADLEW=$GRADLEW"
    "$ADB" version
    ;;
  help|*)
    cat <<EOF
usage: ops/android_bootstrap_bridge.sh <command>

commands:
  native     build the Zig native bridge
  apk        build the Android debug APK
  install    install the current debug APK
  launch     launch the bootstrap activity
  deploy     build native + build APK + install + launch
  clean      clean the Android Gradle project
  reinstall  uninstall package, then install + launch
  logcat     print focused bootstrap logs
  doctor     print resolved SDK/tool paths
EOF
    ;;
esac
