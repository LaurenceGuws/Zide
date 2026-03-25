#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  cat <<'EOF'
Usage:
  scripts/linux/install-local/deploy_channels.sh [--skip-build]

Installs both local Linux install-local channels:
  - zide-stable
  - zide-dev
EOF
  exit 0
fi

"$root/scripts/linux/install-local/deploy_channel.sh" stable "$@"
"$root/scripts/linux/install-local/deploy_channel.sh" dev "$@"

echo "Done: installed both channels (stable + dev)."
