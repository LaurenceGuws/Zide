#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/config/grammar_packs.json"
base_dir="$root/dist"
manifest="$base_dir/manifest.json"

version=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("version",""))
PY
)

if [[ -z "$version" ]]; then
  echo "Missing version in config" >&2
  exit 1
fi

printf '{\n  "version": "%s",\n  "artifacts": [\n' "$version" > "$manifest"

first=1
while IFS= read -r -d '' file; do
  rel=${file#"$base_dir/"}
  sha=$(sha256sum "$file" | awk '{print $1}')
  size=$(stat -c %s "$file")
  if [[ $first -eq 0 ]]; then
    printf ',\n' >> "$manifest"
  fi
  first=0
  printf '    {"path": "%s", "sha256": "%s", "size": %s}' "$rel" "$sha" "$size" >> "$manifest"
 done < <(find "$base_dir" -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.dll" -o -name "*.scm" \) -print0 | sort -z)

printf '\n  ]\n}\n' >> "$manifest"

echo "Wrote $manifest"
