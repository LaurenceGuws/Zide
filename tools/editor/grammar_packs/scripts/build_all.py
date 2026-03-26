#!/usr/bin/env python3
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import sys


LANG_RE = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*{\s*$")
INSTALL_INFO_RE = re.compile(r"^\s*install_info\s*=\s*{\s*$")
KV_RE = re.compile(r"^\s*([A-Za-z_]+)\s*=\s*'([^']+)'\s*,?\s*$")


def parse_parsers_lua(parsers_path: Path) -> dict[str, dict[str, object]]:
    found: dict[str, dict[str, object]] = {}
    current_lang = None
    in_lang = False
    in_install = False
    install: dict[str, object] = {}

    with parsers_path.open("r", encoding="utf-8") as f:
        for line in f:
            indent = len(line) - len(line.lstrip(" "))
            match = LANG_RE.match(line)
            if indent == 2 and match:
                current_lang = match.group(1)
                in_lang = True
                in_install = False
                install = {}
                continue

            if not in_lang:
                continue

            if INSTALL_INFO_RE.match(line):
                in_install = True
                continue

            if in_install:
                if line.strip().startswith("}"):
                    in_install = False
                    continue
                kv = KV_RE.match(line)
                if kv:
                    install[kv.group(1)] = kv.group(2)
                elif "files" in line:
                    files = re.findall(r"'([^']+)'", line)
                    if files:
                        install["files"] = files
                continue

            if indent == 2 and line.strip().startswith("}"):
                if install:
                    found[current_lang] = dict(install)
                in_lang = False
                current_lang = None
                install = {}

    return found


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    config_path = root / "config" / "grammar_packs.json"
    work = root / "work"

    if not config_path.is_file():
        raise SystemExit(f"Missing config: {config_path}")

    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    version = cfg.get("version")
    targets = cfg.get("targets", [])
    exclude = set(cfg.get("exclude_languages", []))
    skip_langs = {s.strip() for s in os.environ.get("ZIDE_GRAMMAR_SKIP", "").split(",") if s.strip()}
    continue_on_error = os.environ.get("ZIDE_GRAMMAR_CONTINUE") == "1"
    target_allow = {s.strip() for s in os.environ.get("ZIDE_GRAMMAR_TARGETS", "").split(",") if s.strip()}
    target_skip = {s.strip() for s in os.environ.get("ZIDE_GRAMMAR_SKIP_TARGETS", "").split(",") if s.strip()}
    try:
        jobs = max(1, int(os.environ.get("ZIDE_GRAMMAR_JOBS", "1") or "1"))
    except ValueError:
        jobs = 1

    if not version:
        raise SystemExit("Missing version in config")
    if not targets:
        raise SystemExit("Missing targets in config")

    parsers_path = work / "parsers.lua"
    if not parsers_path.is_file():
        raise SystemExit("Missing work/parsers.lua. Run sync_from_nvim first.")

    found = parse_parsers_lua(parsers_path)

    tasks = []
    build_pack_py = root / "scripts" / "build_pack.py"
    for lang, info in sorted(found.items()):
        if lang in exclude or lang in skip_langs:
            continue
        url = info.get("url")
        if not url:
            continue
        repo_name = str(url).rstrip("/").split("/")[-1]
        repo_path = work / "grammars" / repo_name
        location = str(info.get("location", ""))
        files = list(info.get("files", []))
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
            cmd = [sys.executable, str(build_pack_py), lang, version, os_name, arch, str(repo_path), location, *files]
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
        failures = []
        counter = {"done": 0}

        def run_task(task):
            lang, os_name, arch, cmd = task
            counter["done"] += 1
            idx = counter["done"]
            print(f"[{idx}/{total}] building {lang} {os_name}/{arch}")
            try:
                subprocess.check_call(cmd)
                return None
            except subprocess.CalledProcessError as exc:
                return (lang, os_name, arch, exc)

        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
            futures = [pool.submit(run_task, task) for task in tasks]
            for fut in concurrent.futures.as_completed(futures):
                err = fut.result()
                if err:
                    failures.append(err)
                    print(f"Build failed for {err[0]} {err[1]}/{err[2]}: {err[3]}")
                    if not continue_on_error:
                        raise err[3]
        if failures and not continue_on_error:
            raise subprocess.CalledProcessError(1, "build_pack.py")

    subprocess.check_call([sys.executable, str(root / "scripts" / "package_queries.py"), str(root)])
    subprocess.check_call([sys.executable, str(root / "scripts" / "generate_manifest.py"), str(root)])

    repo_root = root.parent.parent
    syntax_out = repo_root / "assets" / "syntax" / "generated.lua"
    filetype_lua = repo_root / "dev_references" / "editors" / "neovim" / "runtime" / "lua" / "vim" / "filetype.lua"
    if filetype_lua.is_file() and parsers_path.is_file():
        subprocess.check_call(
            [
                sys.executable,
                str(root / "scripts" / "generate_syntax_registry.py"),
                str(filetype_lua),
                str(parsers_path),
                str(syntax_out),
                version,
            ]
        )
        print(f"Wrote {syntax_out}")
    else:
        print("Skipping syntax registry generation (missing filetype.lua or parsers.lua)", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
