#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: tools/mode_gates.sh <fast|full|gui-smokes>

  fast           Run non-interactive fast MODE gates (no terminal replay)
  full           Run full non-interactive MODE gates (includes terminal replay --all)
  gui-smokes     Run interactive GUI smokes (manual verification flow)
EOF
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

case "$1" in
fast)
    exec zig build mode-gates-fast
    ;;
full)
    exec zig build mode-gates
    ;;
gui-smokes)
    exec zig build gui-smokes-manual
    ;;
*)
    usage
    exit 2
    ;;
esac
