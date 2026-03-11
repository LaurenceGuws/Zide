#!/usr/bin/env python3
"""
Create a harness_api terminal redraw fixture from captured baseline/update bytes.

This tool does not guess expected damage. It creates the fixture skeleton plus
an empty `.vt` sidecar so `terminal-replay --update-goldens` can be used to
generate the golden after the expected damage bounds are filled in.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a harness_api redraw fixture skeleton from baseline/update captures."
    )
    parser.add_argument("--name", help="Fixture stem, written under fixtures/terminal/")
    parser.add_argument("--rows", type=int, help="Viewport rows")
    parser.add_argument("--cols", type=int, help="Viewport cols")
    parser.add_argument(
        "--baseline-file",
        help="UTF-8 text file containing the baseline terminal byte stream",
    )
    parser.add_argument(
        "--update-file",
        action="append",
        dest="update_files",
        help="UTF-8 text file containing one update/output chunk; repeat for multi-packet redraws",
    )
    parser.add_argument(
        "--manifest-file",
        help="Manifest emitted by terminal_capture_redraw_fixture.py; fills name/rows/cols/baseline/update files",
    )
    parser.add_argument(
        "--line-ending",
        default="lf",
        choices=("lf", "crlf", "cr"),
        help="Harness line ending normalization mode",
    )
    parser.add_argument(
        "--fixture-dir",
        default="fixtures/terminal",
        help="Fixture directory root",
    )
    args = parser.parse_args()

    if args.manifest_file:
        manifest = json.loads(Path(args.manifest_file).read_text(encoding="utf-8"))
        args.name = args.name or manifest["name"]
        args.rows = args.rows or int(manifest["rows"])
        args.cols = args.cols or int(manifest["cols"])
        args.line_ending = args.line_ending or manifest.get("line_ending", "lf")
        args.baseline_file = args.baseline_file or manifest["baseline"]["output_file"]
        if not args.update_files:
            args.update_files = [entry["output_file"] for entry in manifest["updates"]]

    if not args.name or args.rows is None or args.cols is None or not args.baseline_file or not args.update_files:
        parser.error("provide name/rows/cols/baseline/update inputs directly or via --manifest-file")

    fixture_dir = Path(args.fixture_dir)
    fixture_dir.mkdir(parents=True, exist_ok=True)

    fixture_path = fixture_dir / f"{args.name}.json"
    vt_path = fixture_dir / f"{args.name}.vt"

    baseline = read_text(Path(args.baseline_file))
    output_chunks = [read_text(Path(path)) for path in args.update_files]

    fixture = {
        "fixture_type": "harness_api",
        "rows": args.rows,
        "cols": args.cols,
        "cursor": {"row": 0, "col": 0},
        "line_ending": args.line_ending,
        "baseline_input": baseline,
        "output_chunks": output_chunks,
        "assertions": ["grid", "damage"],
        "expected_dirty": "partial",
        "expected_damage": {
            "start_row": 0,
            "end_row": 0,
            "start_col": 0,
            "end_col": 0,
        },
    }

    fixture_path.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
    vt_path.write_text("", encoding="utf-8")

    print(f"wrote {fixture_path}")
    print(f"wrote {vt_path}")
    print("next:")
    print(f"  1. set expected_damage in {fixture_path.name}")
    print(f"  2. run: zig build test-terminal-replay -- --fixture {args.name} --update-goldens")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
