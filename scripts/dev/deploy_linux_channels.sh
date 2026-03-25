#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/scripts/linux/install-local/deploy_channels.sh" "$@"
