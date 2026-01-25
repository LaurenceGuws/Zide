#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_root=$(cd "$root/../.." && pwd)
config="$root/config/grammar_packs.json"
work="$root/work"

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
skip_env = os.environ.get("ZIDE_GRAMMAR_SKIP", "")
skip_langs = {s.strip() for s in skip_env.split(",") if s.strip()}
continue_on_error = os.environ.get("ZIDE_GRAMMAR_CONTINUE") == "1"
target_env = os.environ.get("ZIDE_GRAMMAR_TARGETS", "")
skip_target_env = os.environ.get("ZIDE_GRAMMAR_SKIP_TARGETS", "")
target_allow = {s.strip() for s in target_env.split(",") if s.strip()}
target_skip = {s.strip() for s in skip_target_env.split(",") if s.strip()}
jobs_env = os.environ.get("ZIDE_GRAMMAR_JOBS", "")
try:
    jobs = max(1, int(jobs_env)) if jobs_env else 1
except ValueError:
    jobs = 1

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
tasks = []
for lang, info in sorted(found.items()):
    if lang in exclude or lang in skip_langs:
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
        target_key = f"{os_name}/{arch}"
        if target_allow and target_key not in target_allow:
            continue
        if target_key in target_skip:
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
        tasks.append((lang, os_name, arch, cmd))

total = len(tasks)
if jobs <= 1:
    for idx, (lang, os_name, arch, cmd) in enumerate(tasks, start=1):
        print(f"[{idx}/{total}] building {lang} {os_name}/{arch}")
        try:
            subprocess.check_call(cmd)
        except subprocess.CalledProcessError as exc:
            print(f"Build failed for {lang} {os_name}/{arch}: {exc}")
            if not continue_on_error:
                raise
else:
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading

    counter = {"done": 0}
    lock = threading.Lock()

    def run_task(task):
        lang, os_name, arch, cmd = task
        with lock:
            counter["done"] += 1
            idx = counter["done"]
            print(f"[{idx}/{total}] building {lang} {os_name}/{arch}")
        try:
            subprocess.check_call(cmd)
            return None
        except subprocess.CalledProcessError as exc:
            return (lang, os_name, arch, exc)

    failures = []
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = [pool.submit(run_task, task) for task in tasks]
        for fut in as_completed(futures):
            err = fut.result()
            if err:
                failures.append(err)
                print(f"Build failed for {err[0]} {err[1]}/{err[2]}: {err[3]}")
                if not continue_on_error:
                    raise err[3]

    if failures and not continue_on_error:
        raise subprocess.CalledProcessError(1, "build_pack.sh")

PY

# Package queries
"$root/scripts/package_queries.sh"
"$root/scripts/generate_manifest.sh"

syntax_out="$repo_root/assets/syntax/default.lua"
filetype_lua="$repo_root/reference_repos/editors/neovim/runtime/lua/vim/filetype.lua"
parsers_lua="$work/parsers.lua"
if [[ -f "$filetype_lua" && -f "$parsers_lua" ]]; then
  python3 "$root/scripts/generate_syntax_registry.py" "$filetype_lua" "$parsers_lua" "$syntax_out" "$version"
  echo "Wrote $syntax_out"
else
  echo "Skipping syntax registry generation (missing filetype.lua or parsers.lua)" >&2
fi
