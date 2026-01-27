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
query_names = {
    "highlights",
    "injections",
    "locals",
    "tags",
    "textobjects",
    "indents",
}

queries_dir = os.path.join(work, "queries")
if not os.path.isdir(queries_dir):
    sys.exit("Missing work/queries. Run scripts/sync_from_nvim.sh first.")

for name in os.listdir(queries_dir):
    if not name.endswith(".scm"):
        continue
    lang = None
    query = None
    for candidate in query_names:
        suffix = f"_{candidate}.scm"
        if name.endswith(suffix):
            lang = name[: -len(suffix)]
            query = candidate
            break
    if not lang or not query:
        continue
    if lang in exclude:
        continue
    src = os.path.join(queries_dir, name)
    dest_dir = os.path.join(root, "dist", lang, version)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, f"{lang}_{version}_{query}.scm")
    if os.path.exists(dest):
        os.remove(dest)
    with open(src, "rb") as fsrc, open(dest, "wb") as fdst:
        fdst.write(fsrc.read())
    print(f"Packaged {lang} {query}")
PY
