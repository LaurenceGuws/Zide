#!/usr/bin/env python3
import shutil
import subprocess
from pathlib import Path
import sys


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    work = root / "work"
    work.mkdir(parents=True, exist_ok=True)

    nvim_dir = work / "nvim-treesitter"
    if not (nvim_dir / ".git").is_dir():
        print("Cloning nvim-treesitter...")
        subprocess.check_call(["git", "clone", "--depth", "1", "https://github.com/nvim-treesitter/nvim-treesitter.git", str(nvim_dir)])
    else:
        print("Updating nvim-treesitter...")
        subprocess.check_call(["git", "-C", str(nvim_dir), "fetch", "--depth", "1", "origin"])
        subprocess.check_call(["git", "-C", str(nvim_dir), "reset", "--hard", "origin/HEAD"])

    queries_src = nvim_dir / "runtime" / "queries"
    queries_dst = work / "queries"
    queries_dst.mkdir(parents=True, exist_ok=True)

    query_files = [
        "highlights.scm",
        "injections.scm",
        "locals.scm",
        "tags.scm",
        "textobjects.scm",
        "indents.scm",
    ]

    for lang_dir in queries_src.iterdir():
        if not lang_dir.is_dir():
            continue
        lang = lang_dir.name
        for name in query_files:
            src = lang_dir / name
            if not src.is_file():
                continue
            shutil.copyfile(src, queries_dst / f"{lang}_{src.stem}.scm")

    markdown_injections = queries_dst / "markdown_injections.scm"
    if markdown_injections.is_file():
        needle = '(#set! injection.language "markdown_inline")'
        insert = needle + "\n  (#set! injection.include-children)"
        data = markdown_injections.read_text(encoding="utf-8")
        if "injection.include-children" not in data and needle in data:
            markdown_injections.write_text(data.replace(needle, insert), encoding="utf-8")

    shutil.copyfile(nvim_dir / "lua" / "nvim-treesitter" / "parsers.lua", work / "parsers.lua")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
