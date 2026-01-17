#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/config/grammar_packs.json"
work="$root/work"

python3 - "$config" "$work" "$root" <<'PY'
import json
import os
import sys

config_path, work, root = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)
version = cfg.get("version")
exclude = set(cfg.get("exclude_languages", []))

queries_dir = os.path.join(work, "queries")
if not os.path.isdir(queries_dir):
    sys.exit("Missing work/queries. Run scripts/sync_from_nvim.sh first.")

for name in os.listdir(queries_dir):
    if not name.endswith("_highlights.scm"):
        continue
    lang = name.replace("_highlights.scm", "")
    if lang in exclude:
        continue
    src = os.path.join(queries_dir, name)
    dest_dir = os.path.join(root, "dist", lang, version)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, f"{lang}_{version}_highlights.scm")
    if os.path.exists(dest):
        os.remove(dest)
    with open(src, "rb") as fsrc, open(dest, "wb") as fdst:
        fdst.write(fsrc.read())
    print(f"Packaged {lang} highlights")
PY
