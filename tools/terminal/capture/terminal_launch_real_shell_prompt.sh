#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$repo_root"

rows=${ZIDE_TERMINAL_ROWS:-64}
cols=${ZIDE_TERMINAL_COLS:-300}
shell_path=${ZIDE_TERMINAL_SHELL:-${SHELL:-/usr/bin/bash}}

exec ./zig-out/bin/zide-terminal \
  --rows "$rows" \
  --cols "$cols" \
  --shell "$shell_path" \
  "$@"
