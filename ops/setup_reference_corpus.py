#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_ROOT = REPO_ROOT / "dev_references"
INVENTORY_PATH = SCRIPT_DIR / "reference_corpus_inventory.json"


def load_inventory() -> dict[str, list[dict[str, object]]]:
    with INVENTORY_PATH.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)
    if not isinstance(raw, dict):
        raise ValueError("inventory root must be an object")
    return raw


def parse_args(group_names: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Populate the local development reference corpus used for "
            "architectural comparison and source review."
        )
    )
    parser.add_argument(
        "--root-dir",
        type=Path,
        default=DEFAULT_ROOT,
        help="Override the destination root (default: %(default)s).",
    )
    parser.add_argument(
        "--groups",
        nargs="+",
        choices=group_names,
        default=group_names,
        help="Reference groups to populate (default: all groups).",
    )
    parser.add_argument(
        "--only",
        nargs="+",
        default=[],
        metavar="NAME",
        help="Clone only the named references.",
    )
    parser.add_argument(
        "--no-depth",
        action="store_true",
        help="Do not request shallow clones.",
    )
    return parser.parse_args()


def run(cmd: list[str], cwd: Path | None = None) -> bool:
    try:
        subprocess.run(cmd, cwd=cwd, check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def clone_repo(root_dir: Path, spec: dict[str, object], no_depth: bool) -> None:
    name = str(spec["name"])
    url = str(spec["url"])
    dest = root_dir / name
    if dest.exists():
        print(f"skip {name} (already exists)")
        return

    cmd = ["git", "clone"]
    sparse_paths = spec.get("sparse_paths")
    if not no_depth:
        cmd += ["--depth", "1"]
    if sparse_paths:
        cmd += ["--filter=blob:none", "--sparse"]
    cmd += [url, str(dest)]

    print(f"clone {name} -> {dest}")
    if not run(cmd):
        print(f"failed {url}", file=sys.stderr)
        return

    if sparse_paths:
        sparse_cmd = ["git", "sparse-checkout", "set"] + [str(path) for path in sparse_paths]
        if not run(sparse_cmd, cwd=dest):
            print(f"failed sparse-checkout for {url}", file=sys.stderr)


def main() -> int:
    if shutil.which("git") is None:
        print("git not found on PATH", file=sys.stderr)
        return 1

    inventory = load_inventory()
    group_names = list(inventory.keys())
    args = parse_args(group_names)
    only = set(args.only)

    args.root_dir.mkdir(parents=True, exist_ok=True)

    for group_name in args.groups:
        group_root = args.root_dir / group_name
        group_root.mkdir(parents=True, exist_ok=True)
        for spec in inventory[group_name]:
            if only and str(spec["name"]) not in only:
                continue
            clone_repo(group_root, spec, args.no_depth)

    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
