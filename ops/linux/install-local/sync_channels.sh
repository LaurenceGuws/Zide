#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  cat <<'EOF'
Usage:
  ops/linux/install-local/sync_channels.sh [--skip-build]

Replaces both local Linux install-local channels in-place:
  - zide-stable
  - zide-dev
EOF
  exit 0
fi

"$root/ops/linux/install-local/sync_channel.sh" stable "$@"
"$root/ops/linux/install-local/sync_channel.sh" dev "$@"

echo "Done: synced both channels (stable + dev)."
