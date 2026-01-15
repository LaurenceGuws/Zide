#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap script for zide dependencies
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_ROOT/vendor"

# Versions (can be overridden via environment)
LIBVTERM_REF="${LIBVTERM_REF:-v0.3.3}"
RAYLIB_REF="${RAYLIB_REF:-5.5}"
FORCE="${FORCE:-}"

echo "==> Bootstrapping zide dependencies"
echo "    Project root: $PROJECT_ROOT"
echo "    Vendor dir: $VENDOR_DIR"

mkdir -p "$VENDOR_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# libvterm
# ─────────────────────────────────────────────────────────────────────────────
LIBVTERM_DIR="$VENDOR_DIR/libvterm"

if [[ -d "$LIBVTERM_DIR" && -z "$FORCE" ]]; then
    echo "==> libvterm already exists, skipping (use FORCE=1 to overwrite)"
else
    echo "==> Fetching libvterm ($LIBVTERM_REF)..."
    rm -rf "$LIBVTERM_DIR"
    
    git clone --depth 1 --branch "$LIBVTERM_REF" \
        https://github.com/neovim/libvterm.git \
        "$LIBVTERM_DIR" 2>/dev/null || \
    git clone --depth 1 \
        https://github.com/neovim/libvterm.git \
        "$LIBVTERM_DIR"
    
    rm -rf "$LIBVTERM_DIR/.git"
    
    # Generate .inc files from .tbl files
    echo "==> Generating libvterm encoding tables..."
    cd "$LIBVTERM_DIR"
    if [[ -f "tbl2inc_c.pl" ]]; then
        mkdir -p src/encoding
        for tbl in src/encoding/*.tbl; do
            if [[ -f "$tbl" ]]; then
                inc="${tbl%.tbl}.inc"
                perl tbl2inc_c.pl "$tbl" > "$inc"
                echo "    Generated: $inc"
            fi
        done
    fi
    cd "$PROJECT_ROOT"
    
    echo "==> libvterm ready"
fi

# ─────────────────────────────────────────────────────────────────────────────
# raylib
# ─────────────────────────────────────────────────────────────────────────────
RAYLIB_DIR="$VENDOR_DIR/raylib"

if [[ -d "$RAYLIB_DIR" && -z "$FORCE" ]]; then
    echo "==> raylib already exists, skipping (use FORCE=1 to overwrite)"
else
    echo "==> Fetching raylib ($RAYLIB_REF)..."
    rm -rf "$RAYLIB_DIR"
    
    git clone --depth 1 --branch "$RAYLIB_REF" \
        https://github.com/raysan5/raylib.git \
        "$RAYLIB_DIR" 2>/dev/null || \
    git clone --depth 1 \
        https://github.com/raysan5/raylib.git \
        "$RAYLIB_DIR"
    
    rm -rf "$RAYLIB_DIR/.git"
    echo "==> raylib ready"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete!"
echo "    - libvterm: $LIBVTERM_DIR"
echo "    - raylib: $RAYLIB_DIR"
echo ""
echo "    To build: zig build"
echo "    To run:   zig build run"
