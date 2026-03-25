#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/linux/install-local/sync_channel.sh <stable|dev> [--skip-build]

Replaces one local Linux launcher family in-place by removing any existing
channel install and deploying the current repo build for that channel.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

root="$(cd "$(dirname "$0")/../../.." && pwd)"
channel="$1"
shift

"$root/scripts/linux/install-local/remove_channel.sh" "$channel"
"$root/scripts/linux/install-local/deploy_channel.sh" "$channel" "$@"

echo "Done: synced Linux install-local channel '$channel'."
