#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <zide-terminal-bin> <output-dir> [assets-dir]" >&2
  exit 2
fi

BIN_PATH="$1"
OUT_DIR="$2"
ASSETS_DIR="${3:-assets}"
BIN_DIR="$OUT_DIR/bin"
LIB_DIR="$OUT_DIR/lib"
LAUNCHER="$OUT_DIR/zide-terminal"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "missing binary: $BIN_PATH" >&2
  exit 1
fi
if [[ ! -d "$ASSETS_DIR" ]]; then
  echo "missing assets dir: $ASSETS_DIR" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$LIB_DIR"
cp -f "$BIN_PATH" "$BIN_DIR/zide-terminal"
rm -rf "$OUT_DIR/assets"
cp -a "$ASSETS_DIR" "$OUT_DIR/assets"

# Parse ldd output and copy non-core libs into bundle/lib.
ldd "$BIN_PATH" \
  | awk '
      /=>/ { print $3; next }
      /^\// { print $1; next }
    ' \
  | while IFS= read -r so; do
      [[ -n "$so" ]] || continue
      [[ -f "$so" ]] || continue
      base="$(basename "$so")"
      case "$base" in
        linux-vdso.so.*|ld-linux*.so.*|libc.so.*|libm.so.*|libpthread.so.*|librt.so.*|libdl.so.*)
          continue
          ;;
      esac
      cp -f "$so" "$LIB_DIR/$base"
    done

cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(dirname -- "$(readlink -f -- "$0")")"
export LD_LIBRARY_PATH="$SELF_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$SELF_DIR"
exec "$SELF_DIR/bin/zide-terminal" "$@"
EOF
chmod +x "$LAUNCHER"

echo "bundled terminal at: $OUT_DIR"
