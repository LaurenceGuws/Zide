#!/usr/bin/env bash
set -euo pipefail

# Build a Tree-sitter grammar pack as a standalone shared library.
# Usage: build_pack.sh <language> <version> <os> <arch> <repo_path> [location] [files...]

lang=${1:?language required}
version=${2:?version required}
os=${3:?os required}
arch=${4:?arch required}
repo_path=${5:?repo path required}
location=${6:-}
shift 6 || true
files=("$@")

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work="$root/work"

case "$os" in
  linux) ext="so" ;;
  android) ext="so" ;;
  macos) ext="dylib" ;;
  windows) ext="dll" ;;
  *) echo "Unsupported OS: $os" >&2; exit 1 ;;
 esac

case "$os/$arch" in
  linux/x86_64) target="x86_64-linux-gnu" ;;
  linux/aarch64) target="aarch64-linux-gnu" ;;
  android/x86_64) target="x86_64-linux-android" ;;
  android/aarch64) target="aarch64-linux-android" ;;
  android/armv7) target="arm-linux-androideabi" ;;
  macos/x86_64) target="x86_64-macos" ;;
  macos/aarch64) target="aarch64-macos" ;;
  windows/x86_64) target="x86_64-windows-gnu" ;;
  *) echo "Unsupported target: $os/$arch" >&2; exit 1 ;;
 esac

out_dir="$root/dist/${lang}/${version}"
mkdir -p "$out_dir"

out_name="${lang}_${version}_${os}_${arch}.${ext}"
out_path="$out_dir/$out_name"

base_dir="$repo_path"
if [[ -n "$location" ]]; then
  base_dir="$repo_path/$location"
fi

sources=("$work/tree-sitter/lib/src/lib.c")
if [[ ${#files[@]} -gt 0 ]]; then
  for file in "${files[@]}"; do
    sources+=("$base_dir/$file")
  done
else
  sources+=("$base_dir/src/parser.c")
  if [[ -f "$base_dir/src/scanner.c" ]]; then
    sources+=("$base_dir/src/scanner.c")
  fi
fi

cflags=("-std=c99")
if [[ "$os" != "windows" ]]; then
  cflags+=("-D_POSIX_C_SOURCE=200809L" "-D_DEFAULT_SOURCE" "-D_GNU_SOURCE")
fi

android_cc=""
if [[ "$os" == "android" ]]; then
  android_api="${ANDROID_API:-29}"
  if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    ndk_root="$ANDROID_NDK_ROOT"
  elif [[ -n "${ANDROID_HOME:-}" ]]; then
    ndk_root="$ANDROID_HOME/ndk"
  else
    ndk_root=""
  fi

  if [[ -d "$ndk_root" && ! -d "$ndk_root/toolchains" ]]; then
    ndk_root=$(ls -d "$ndk_root"/* 2>/dev/null | sort -V | tail -n 1 || true)
  fi

  if [[ -z "$ndk_root" || ! -d "$ndk_root" ]]; then
    echo "ANDROID_NDK_ROOT not set and no NDK found under ANDROID_HOME/ndk" >&2
    exit 1
  fi

  host_tag="linux-x86_64"
  clang_bin="$ndk_root/toolchains/llvm/prebuilt/$host_tag/bin"
  case "$arch" in
    aarch64) android_cc="$clang_bin/aarch64-linux-android${android_api}-clang" ;;
    x86_64) android_cc="$clang_bin/x86_64-linux-android${android_api}-clang" ;;
    armv7) android_cc="$clang_bin/armv7a-linux-androideabi${android_api}-clang" ;;
  esac
  if [[ ! -x "$android_cc" ]]; then
    echo "Android clang not found: $android_cc" >&2
    exit 1
  fi
fi

if [[ "$os" == "android" ]]; then
  "$android_cc" \
    -shared \
    -fPIC \
    -O2 \
    -o "$out_path" \
    -I "$work/tree-sitter/lib/include" \
    -I "$work/tree-sitter/lib/src" \
    -I "$base_dir/src" \
    "${cflags[@]}" \
    "${sources[@]}"
else
  zig build-lib \
    -dynamic \
    -OReleaseFast \
    -target "$target" \
    -femit-bin="$out_path" \
    -I "$work/tree-sitter/lib/include" \
    -I "$work/tree-sitter/lib/src" \
    -I "$base_dir/src" \
    -lc \
    -cflags "${cflags[@]}" -- \
    "${sources[@]}"
fi

echo "Built $out_path"
