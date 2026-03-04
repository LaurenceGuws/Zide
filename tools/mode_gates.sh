#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: tools/mode_gates.sh <fast|full|manual-smokes>

  fast           Run non-interactive fast MODE gates (no terminal replay)
  full           Run full non-interactive MODE gates (includes terminal replay --all)
  manual-smokes  Run interactive mode smokes (manual verification flow)
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
manual-smokes)
    exec zig build mode-smokes-manual
    ;;
*)
    usage
    exit 2
    ;;
esac
