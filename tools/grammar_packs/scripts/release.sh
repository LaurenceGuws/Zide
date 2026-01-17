#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/config/grammar_packs.json"

if [[ ! -f "$config" ]]; then
  echo "Missing config: $config" >&2
  exit 1
fi

version=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("version",""))
PY
)
release_tag=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("release_tag",""))
PY
)
release_title=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("release_title",""))
PY
)
release_notes=$(python3 - <<PY
import json
cfg=json.load(open("$config","r",encoding="utf-8"))
print(cfg.get("release_notes",""))
PY
)

if [[ -z "$version" || -z "$release_tag" ]]; then
  echo "Missing version/release_tag in config" >&2
  exit 1
fi

"$root/scripts/sync_from_nvim.sh"
"$root/scripts/fetch_grammars.sh"
"$root/scripts/build_all.sh"

if ! gh release view "$release_tag" >/dev/null 2>&1; then
  gh release create "$release_tag" -t "$release_title" -n "$release_notes"
fi

"$root/scripts/publish.sh"
