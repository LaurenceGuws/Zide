#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap script for zide dependencies
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_ROOT/vendor"

# Versions (can be overridden via environment)
RAYLIB_REF="${RAYLIB_REF:-5.5}"
FORCE="${FORCE:-}"

echo "==> Bootstrapping zide dependencies"
echo "    Project root: $PROJECT_ROOT"
echo "    Vendor dir: $VENDOR_DIR"

mkdir -p "$VENDOR_DIR"

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
echo "    - raylib: $RAYLIB_DIR"
echo ""
echo "    To build: zig build"
echo "    To run:   zig build run"
