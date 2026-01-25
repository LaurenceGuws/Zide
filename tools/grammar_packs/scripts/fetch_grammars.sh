#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work="$root/work"

mkdir -p "$work/grammars"

# Ensure tree-sitter runtime
runtime_dir="$work/tree-sitter"
if [[ ! -d "$runtime_dir/.git" ]]; then
  echo "Cloning Tree-sitter runtime"
  git clone --depth 1 https://github.com/tree-sitter/tree-sitter.git "$runtime_dir"
else
  echo "Updating Tree-sitter runtime"
  git -C "$runtime_dir" fetch --depth 1 origin
  git -C "$runtime_dir" reset --hard origin/HEAD
fi

parsers="$work/parsers.lua"
if [[ ! -f "$parsers" ]]; then
  echo "Missing work/parsers.lua. Run scripts/sync_from_nvim.sh first." >&2
  exit 1
fi

python3 - "$parsers" "$work/grammars" <<'PY'
import os
import re
import subprocess
import sys

parsers_path = sys.argv[1]
out_dir = sys.argv[2]

lang_re = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*{\s*$")
install_info_re = re.compile(r"^\s*install_info\s*=\s*{\s*$")
kv_re = re.compile(r"^\s*([A-Za-z_]+)\s*=\s*'([^']+)'\s*,?\s*$")

found = {}
current_lang = None
in_lang = False
in_install = False
lang_indent = 2
install = {}

with open(parsers_path, "r", encoding="utf-8") as f:
    for line in f:
        indent = len(line) - len(line.lstrip(" "))
        if indent == lang_indent and lang_re.match(line):
            current_lang = lang_re.match(line).group(1)
            in_lang = True
            in_install = False
            install = {}
            continue

        if in_lang:
            if install_info_re.match(line):
                in_install = True
                continue

            if in_install:
                if line.strip().startswith("}"):
                    in_install = False
                    continue
                km = kv_re.match(line)
                if km:
                    install[km.group(1)] = km.group(2)
                continue

            if indent == lang_indent and line.strip().startswith("}"):
                if install:
                    found[current_lang] = install
                in_lang = False
                current_lang = None
                install = {}
                continue

for lang, info in sorted(found.items()):
    url = info.get("url")
    rev = info.get("revision")
    if not url:
        continue
    name = url.rstrip("/").split("/")[-1]
    dest = os.path.join(out_dir, name)
    if os.path.isdir(os.path.join(dest, ".git")):
        print(f"Updating {dest}")
        subprocess.check_call(["git", "-C", dest, "fetch", "--depth", "1", "origin"])
    else:
        print(f"Cloning {url}")
        subprocess.check_call(["git", "clone", "--depth", "1", url, dest])

    if rev:
        subprocess.check_call(["git", "-C", dest, "fetch", "--depth", "1", "origin", rev])
        subprocess.check_call(["git", "-C", dest, "checkout", "-f", "FETCH_HEAD"])
PY
