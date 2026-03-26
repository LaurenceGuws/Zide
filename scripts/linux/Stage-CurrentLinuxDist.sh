#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon | head -n1)}"
if [[ -z "$VERSION" ]]; then
  echo "failed to derive VERSION from build.zig.zon" >&2
  exit 1
fi

TAG="${TAG:-v$VERSION}"
TARGET_DIR="releases/$TAG/linux-x86_64-local"
DIST_DIR="$TARGET_DIR/dist"
IDE_BUNDLE_DIR="$TARGET_DIR/zide-ide-bundle"
EDITOR_BUNDLE_DIR="$TARGET_DIR/zide-editor-bundle"
TERMINAL_BUNDLE_DIR="$TARGET_DIR/zide-terminal-bundle"
TERMINAL_FFI_DIR="$TARGET_DIR/zide-terminal-ffi"
EDITOR_FFI_DIR="$TARGET_DIR/zide-editor-ffi"

rm -rf "$IDE_BUNDLE_DIR" "$EDITOR_BUNDLE_DIR" "$TERMINAL_BUNDLE_DIR" "$TERMINAL_FFI_DIR" "$EDITOR_FFI_DIR"
mkdir -p "$DIST_DIR" "$IDE_BUNDLE_DIR" "$EDITOR_BUNDLE_DIR" "$TERMINAL_BUNDLE_DIR" "$TERMINAL_FFI_DIR" "$EDITOR_FFI_DIR"

zig build -Doptimize=ReleaseFast
zig build -Dmode=editor -Doptimize=ReleaseFast
zig build -Dmode=terminal -Doptimize=ReleaseFast
zig build build-terminal-ffi -Doptimize=ReleaseFast
zig build build-editor-ffi -Doptimize=ReleaseFast

bash tools/packaging/linux/bundle_terminal_linux.sh \
  zig-out/bin/zide \
  "$IDE_BUNDLE_DIR" \
  assets \
  ide

bash tools/packaging/linux/bundle_terminal_linux.sh \
  zig-out/bin/zide-editor \
  "$EDITOR_BUNDLE_DIR" \
  assets \
  editor

bash tools/packaging/linux/bundle_terminal_linux.sh \
  zig-out/bin/zide-terminal \
  "$TERMINAL_BUNDLE_DIR" \
  assets \
  terminal

cp zig-out/lib/libzide-terminal-ffi.so "$TERMINAL_FFI_DIR/"
cp include/zide_terminal_ffi.h "$TERMINAL_FFI_DIR/"

cp zig-out/lib/libzide-editor-ffi.so "$EDITOR_FFI_DIR/"
cp include/zide_editor_ffi.h "$EDITOR_FFI_DIR/"

cat > "$TERMINAL_FFI_DIR/RELEASE.txt" <<EOF
product_version=$VERSION
release_tag=$TAG
artifact=zide-terminal-ffi
platform=linux-x86_64
EOF

cat > "$EDITOR_FFI_DIR/RELEASE.txt" <<EOF
product_version=$VERSION
release_tag=$TAG
artifact=zide-editor-ffi
platform=linux-x86_64
EOF

(
  cd "$TARGET_DIR"
  tar -czf "dist/zide-ide-bundle-$VERSION-linux-x86_64.tar.gz" "zide-ide-bundle"
  tar -czf "dist/zide-editor-bundle-$VERSION-linux-x86_64.tar.gz" "zide-editor-bundle"
  tar -czf "dist/zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz" "zide-terminal-bundle"
  tar -czf "dist/zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz" "zide-terminal-ffi"
  tar -czf "dist/zide-editor-ffi-$VERSION-linux-x86_64.tar.gz" "zide-editor-ffi"
)

(
  cd "$DIST_DIR"
  sha256sum \
    "zide-ide-bundle-$VERSION-linux-x86_64.tar.gz" \
    "zide-editor-bundle-$VERSION-linux-x86_64.tar.gz" \
    "zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz" \
    "zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz" \
    "zide-editor-ffi-$VERSION-linux-x86_64.tar.gz" \
    > SHA256SUMS-linux-x86_64.txt
)

echo "staged local linux dist at: $DIST_DIR"
