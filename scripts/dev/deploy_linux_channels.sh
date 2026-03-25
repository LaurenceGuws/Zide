#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  cat <<'EOF'
Usage:
  scripts/dev/deploy_linux_channels.sh [--skip-build]

Installs both local Linux dev channels:
  - zide-stable (ReleaseFast)
  - zide-dev (debug/dev)
EOF
  exit 0
fi

"$root/scripts/dev/deploy_linux_channel.sh" stable "$@"
"$root/scripts/dev/deploy_linux_channel.sh" dev "$@"

echo "Done: installed both channels (stable + dev)."
