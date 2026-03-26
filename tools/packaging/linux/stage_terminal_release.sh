#!/usr/bin/env bash
set -euo pipefail

echo "tools/packaging/linux/stage_terminal_release.sh is deprecated; use scripts/linux/Stage-CurrentLinuxDist.sh" >&2
exec "$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/linux/Stage-CurrentLinuxDist.sh"
