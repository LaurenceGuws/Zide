#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "usage: $0 <zide-bin> <output-dir> [assets-dir] [mode]" >&2
  exit 2
fi

BIN_PATH="$1"
OUT_DIR="$2"
ASSETS_DIR="${3:-assets}"
MODE="${4:-auto}"
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

if [[ "$MODE" == "auto" ]]; then
  case "$(basename "$BIN_PATH")" in
    zide-terminal) MODE="terminal" ;;
    zide-editor) MODE="editor" ;;
    *) MODE="ide" ;;
  esac
fi
case "$MODE" in
  terminal|editor|ide) ;;
  *)
    echo "invalid mode: $MODE (expected terminal|editor|ide|auto)" >&2
    exit 1
    ;;
esac

copy_assets_for_mode() {
  local src_root="$1"
  local dst_root="$2"
  local mode="$3"

  rm -rf "$dst_root"
  mkdir -p "$dst_root"

  local -a keep=()
  case "$mode" in
    terminal)
      keep=(
        config
        fonts
        icon
        terminfo
      )
      ;;
    editor)
      keep=(
        config
        fonts
        icon
        queries
        syntax
      )
      ;;
    ide)
      cp -a "$src_root/." "$dst_root/"
      return 0
      ;;
  esac

  local entry
  for entry in "${keep[@]}"; do
    if [[ -e "$src_root/$entry" ]]; then
      cp -a "$src_root/$entry" "$dst_root/$entry"
    fi
  done
}

mkdir -p "$BIN_DIR" "$LIB_DIR" "$TERMINFO_DIR"
cp -f "$BIN_PATH" "$BIN_DIR/zide-terminal"
copy_assets_for_mode "$ASSETS_DIR" "$OUT_DIR/assets" "$MODE"

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
if [[ ! -f "$TERMINFO_DIR/x/xterm-zide" && ! -f "$TERMINFO_DIR/z/zide-256color" && ! -f "$TERMINFO_DIR/z/zide" ]]; then
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
RUNTIME_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zide-terminal"
export LD_LIBRARY_PATH="$SELF_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ZIDE_LAUNCH_CWD="$LAUNCH_CWD"

mkdir -p "$RUNTIME_DIR"
ln -sfn "$SELF_DIR/assets" "$RUNTIME_DIR/assets"
if [[ -f "$SELF_DIR/.zide.lua" ]]; then
  ln -sfn "$SELF_DIR/.zide.lua" "$RUNTIME_DIR/.zide.lua"
fi

cd "$RUNTIME_DIR"
exec "$SELF_DIR/bin/zide-terminal" "$@"
EOF
chmod +x "$LAUNCHER"

echo "bundled terminal at: $OUT_DIR (mode=$MODE)"
