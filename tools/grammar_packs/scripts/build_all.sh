#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$root/config/grammar_packs.json"
work="$root/work"

if [[ ! -f "$config" ]]; then
  echo "Missing config: $config" >&2
  exit 1
fi

python3 - "$config" "$root" "$work" <<'PY'
import json
import os
import re
import subprocess
import sys

config_path, root, work = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

version = cfg.get("version")
targets = cfg.get("targets", [])
exclude = set(cfg.get("exclude_languages", []))

if not version:
    sys.exit("Missing version in config")
if not targets:
    sys.exit("Missing targets in config")

parsers_path = os.path.join(work, "parsers.lua")
if not os.path.isfile(parsers_path):
    sys.exit("Missing work/parsers.lua. Run scripts/sync_from_nvim.sh first.")

# Parse parsers.lua (top-level language entries only)
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
                elif "files" in line:
                    files = re.findall(r"'([^']+)'", line)
                    if files:
                        install["files"] = files
                continue

            if indent == lang_indent and line.strip().startswith("}"):
                if install:
                    found[current_lang] = install
                in_lang = False
                current_lang = None
                install = {}
                continue

# Build for each language
for lang, info in sorted(found.items()):
    if lang in exclude:
        continue
    url = info.get("url")
    if not url:
        continue
    repo_name = url.rstrip("/").split("/")[-1]
    repo_path = os.path.join(work, "grammars", repo_name)
    location = info.get("location", "")
    files = info.get("files", [])
    for target in targets:
        os_name = target.get("os")
        arch = target.get("arch")
        if not os_name or not arch:
            continue
        cmd = [
            os.path.join(root, "scripts", "build_pack.sh"),
            lang,
            version,
            os_name,
            arch,
            repo_path,
            location,
        ] + files
        subprocess.check_call(cmd)

PY

# Package queries
"$root/scripts/package_queries.sh"
"$root/scripts/generate_manifest.sh"
