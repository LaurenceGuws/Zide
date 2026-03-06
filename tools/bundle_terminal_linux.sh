#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <zide-terminal-bin> <output-dir>" >&2
  exit 2
fi

BIN_PATH="$1"
OUT_DIR="$2"
BIN_DIR="$OUT_DIR/bin"
LIB_DIR="$OUT_DIR/lib"
LAUNCHER="$OUT_DIR/zide-terminal"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "missing binary: $BIN_PATH" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$LIB_DIR"
cp -f "$BIN_PATH" "$BIN_DIR/zide-terminal"

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
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export LD_LIBRARY_PATH="$SELF_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$SELF_DIR/bin/zide-terminal" "$@"
EOF
chmod +x "$LAUNCHER"

echo "bundled terminal at: $OUT_DIR"
