#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_EXPLORER_DIR="$ROOT_DIR/../docs-explorer"
PORT="${1:-8009}"
CONFIG_PATH="$ROOT_DIR/tools/docs_explorer_config/project.zide.json"

if [[ ! -d "$DOCS_EXPLORER_DIR" ]]; then
  echo "docs-explorer checkout is missing"
  echo "clone: git clone https://github.com/LaurenceGuws/docs-explorer \"$DOCS_EXPLORER_DIR\""
  exit 1
fi

if [[ ! -f "$DOCS_EXPLORER_DIR/build/js/main.js" ]]; then
  echo "docs-explorer build output is missing"
  echo "run: cd \"$DOCS_EXPLORER_DIR\" && npm install && npm run build"
  exit 1
fi

cd "$DOCS_EXPLORER_DIR"
python3 docs_explorer.py "$PORT" "$CONFIG_PATH"
