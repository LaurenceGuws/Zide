#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/config/grammar_packs.json"
base_dir="$root/dist"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install GitHub CLI first." >&2
  exit 1
fi

release_tag=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("release_tag",""))
PY
)

if [[ -z "$release_tag" ]]; then
  echo "Missing release_tag in config" >&2
  exit 1
fi

assets=()
while IFS= read -r -d '' file; do
  assets+=("$file")
 done < <(find "$base_dir" -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.dll" -o -name "*.scm" -o -name "manifest.json" \) -print0 | sort -z)

if [[ ${#assets[@]} -eq 0 ]]; then
  echo "No assets found to publish." >&2
  exit 1
fi

gh release upload "$release_tag" "${assets[@]}" --clobber
