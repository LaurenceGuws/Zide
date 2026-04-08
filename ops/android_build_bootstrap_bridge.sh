#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK_ROOT" ]]; then
  if [[ -d "$HOME/.local/share/zide-android-sdk" ]]; then
    SDK_ROOT="$HOME/.local/share/zide-android-sdk"
  else
    SDK_ROOT="/opt/android-sdk"
  fi
fi
NDK_VERSION="${ZIDE_ANDROID_NDK_VERSION:-27.1.12297006}"
if [[ ! -d "$SDK_ROOT/ndk/$NDK_VERSION" && -d "$HOME/.local/share/zide-android-sdk/ndk/$NDK_VERSION" ]]; then
  SDK_ROOT="$HOME/.local/share/zide-android-sdk"
fi
NDK_ROOT="$SDK_ROOT/ndk/$NDK_VERSION"
CLANG="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang"
OBJ_PATH="$ROOT/android/bootstrap-bridge/app/build/native/android_bridge_exports.o"
OUT_DIR="$ROOT/android/bootstrap-bridge/app/src/main/jniLibs/arm64-v8a"
OUT_LIB="$OUT_DIR/libzide_android_bridge.so"

mkdir -p "$OUT_DIR"
mkdir -p "$(dirname "$OBJ_PATH")"

if [[ ! -x "$CLANG" ]]; then
  echo "missing Android clang linker: $CLANG" >&2
  echo "install NDK $NDK_VERSION into $SDK_ROOT before building the bridge" >&2
  exit 1
fi

zig build-obj \
  -target aarch64-linux-android \
  "$ROOT/src/android_bridge_exports.zig" \
  -femit-bin="$OBJ_PATH"

"$CLANG" \
  -shared \
  -Wl,--no-undefined \
  "$OBJ_PATH" \
  -landroid \
  -o "$OUT_LIB"

echo "built $OUT_LIB"
