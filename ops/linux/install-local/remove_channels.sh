#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  cat <<'EOF'
Usage:
  ops/linux/install-local/remove_channels.sh

Removes both local Linux install-local channels:
  - zide-stable
  - zide-dev
EOF
  exit 0
fi

"$root/ops/linux/install-local/remove_channel.sh" stable
"$root/ops/linux/install-local/remove_channel.sh" dev

echo "Done: removed both channels (stable + dev)."
