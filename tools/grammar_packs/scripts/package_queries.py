#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import sys


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    config_path = root / "config" / "grammar_packs.json"
    work = root / "work"

    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    version = cfg.get("version")
    exclude = set(cfg.get("exclude_languages", []))
    query_names = {"highlights", "injections", "locals", "tags", "textobjects", "indents"}

    queries_dir = work / "queries"
    if not queries_dir.is_dir():
        raise SystemExit("Missing work/queries. Run sync_from_nvim first.")

    for path in queries_dir.iterdir():
        if path.suffix != ".scm":
            continue
        lang = None
        query = None
        for candidate in query_names:
            suffix = f"_{candidate}.scm"
            if path.name.endswith(suffix):
                lang = path.name[: -len(suffix)]
                query = candidate
                break
        if not lang or not query or lang in exclude:
            continue
        dest_dir = root / "dist" / lang / version
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{lang}_{version}_{query}.scm"
        if dest.exists():
            dest.unlink()
        shutil.copyfile(path, dest)
        print(f"Packaged {lang} {query}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
