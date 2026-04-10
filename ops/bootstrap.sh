#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: bootstrap.sh [-h|--help]

Bootstrap checked-in vendor dependencies for Zide.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 0 ]]; then
  echo "unexpected arguments: $*" >&2
  usage >&2
  exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap script for zide dependencies
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_ROOT/vendor"

echo "==> Bootstrapping zide dependencies"
echo "    Project root: $PROJECT_ROOT"
echo "    Vendor dir: $VENDOR_DIR"

mkdir -p "$VENDOR_DIR"

echo "==> Vendor deps are checked in (tree-sitter, stb_image). No external fetch needed."

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete!"
echo "    - vendor: $VENDOR_DIR"
echo ""
echo "    To build: zig build"
echo "    To run:   zig build run"
