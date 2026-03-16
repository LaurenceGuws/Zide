#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon | head -n1)}"
if [[ -z "$VERSION" ]]; then
  echo "failed to derive VERSION from build.zig.zon" >&2
  exit 1
fi

TAG="${TAG:-v$VERSION}"
TARGET_DIR="releases/$TAG"
DIST_DIR="$TARGET_DIR/dist"
TERMINAL_BUNDLE_DIR="$TARGET_DIR/zide-terminal-bundle"
TERMINAL_FFI_DIR="$TARGET_DIR/zide-terminal-ffi"

rm -rf "$TERMINAL_BUNDLE_DIR" "$TERMINAL_FFI_DIR"
mkdir -p "$DIST_DIR" "$TERMINAL_BUNDLE_DIR" "$TERMINAL_FFI_DIR"

zig build -Dmode=terminal -Doptimize=ReleaseFast
zig build build-terminal-ffi -Doptimize=ReleaseFast

bash tools/bundle_terminal_linux.sh \
  zig-out/bin/zide-terminal \
  "$TERMINAL_BUNDLE_DIR" \
  assets \
  terminal

cp zig-out/lib/libzide-terminal-ffi.so "$TERMINAL_FFI_DIR/"
cp include/zide_terminal_ffi.h "$TERMINAL_FFI_DIR/"

cat > "$TERMINAL_FFI_DIR/RELEASE.txt" <<EOF
product_version=$VERSION
release_tag=$TAG
artifact=zide-terminal-ffi
platform=linux-x86_64
EOF

(
  cd "$TARGET_DIR"
  tar -czf "dist/zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz" "zide-terminal-bundle"
  tar -czf "dist/zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz" "zide-terminal-ffi"
)

(
  cd "$DIST_DIR"
  sha256sum \
    "zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz" \
    "zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz" \
    > SHA256SUMS
)

echo "staged terminal release artifacts under $TARGET_DIR"
