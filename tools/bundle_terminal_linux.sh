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
TERMINFO_DIR="$OUT_DIR/terminfo"
LAUNCHER="$OUT_DIR/zide-terminal"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "missing binary: $BIN_PATH" >&2
  exit 1
fi
if [[ ! -d "$ASSETS_DIR" ]]; then
  echo "missing assets dir: $ASSETS_DIR" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$LIB_DIR" "$TERMINFO_DIR"
cp -f "$BIN_PATH" "$BIN_DIR/zide-terminal"
rm -rf "$OUT_DIR/assets"
cp -a "$ASSETS_DIR" "$OUT_DIR/assets"

# Compile bundled zide terminfo (required for stable TERM=zide behavior).
if [[ ! -f "terminfo/zide.terminfo" ]]; then
  echo "missing terminfo source: terminfo/zide.terminfo" >&2
  exit 1
fi
if ! command -v tic >/dev/null 2>&1; then
  echo "missing required tool: tic (ncurses terminfo compiler)" >&2
  exit 1
fi
tic -x -o "$TERMINFO_DIR" "terminfo/zide.terminfo"
if [[ ! -f "$TERMINFO_DIR/z/zide-256color" && ! -f "$TERMINFO_DIR/z/zide" ]]; then
  echo "failed to compile bundled zide terminfo into $TERMINFO_DIR" >&2
  exit 1
fi

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
LAUNCH_CWD="${PWD:-$HOME}"
export LD_LIBRARY_PATH="$SELF_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [[ -f "$SELF_DIR/terminfo/z/zide-256color" || -f "$SELF_DIR/terminfo/z/zide" ]]; then
  export TERMINFO="$SELF_DIR/terminfo"
  export TERMINFO_DIRS="$SELF_DIR/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}:/usr/share/terminfo:/usr/lib/terminfo:/lib/terminfo:/etc/terminfo"
fi
export ZIDE_LAUNCH_CWD="$LAUNCH_CWD"
cd "$SELF_DIR"
exec "$SELF_DIR/bin/zide-terminal" "$@"
EOF
chmod +x "$LAUNCHER"

echo "bundled terminal at: $OUT_DIR"
