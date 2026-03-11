#!/usr/bin/env python3
"""
Create a harness_api terminal redraw fixture from captured baseline/update bytes.

This tool can:
- create a fixture skeleton with placeholder damage
- hydrate the expected redraw contract from an observed-state JSON emitted by
  the replay runner
- strip the common baseline prefix/suffix from update captures, so staged PTY
  sessions can be turned into honest update chunks with less manual editing
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def common_prefix_len(a: str, b: str) -> int:
    size = min(len(a), len(b))
    idx = 0
    while idx < size and a[idx] == b[idx]:
        idx += 1
    return idx


def trimmed_prefix_len(a: str, b: str) -> int:
    prefix_len = common_prefix_len(a, b)
    while prefix_len > 0:
        candidate = a[:prefix_len]
        if (
            not candidate.endswith("\x1b")
            and not candidate.endswith("\x1b[")
            and not candidate.endswith("\x9b")
        ):
            return prefix_len
        prefix_len -= 1
    return 0


def common_suffix_len(a: str, b: str) -> int:
    size = min(len(a), len(b))
    idx = 0
    while idx < size and a[len(a) - 1 - idx] == b[len(b) - 1 - idx]:
        idx += 1
    return idx


def trimmed_suffix_len(baseline_tail: str, trimmed: str) -> int:
    suffix_len = common_suffix_len(baseline_tail, trimmed)
    while suffix_len > 0:
        candidate = trimmed[:-suffix_len]
        if (
            not candidate.endswith("\x1b")
            and not candidate.endswith("\x1b[")
            and not candidate.endswith("\x9b")
        ):
            return suffix_len
        suffix_len -= 1
    return 0


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
        "--observed-file",
        help="JSON emitted by terminal-replay --print-observed/--observed-file; fills expected redraw fields",
    )
    parser.add_argument(
        "--strip-baseline-prefix",
        action="store_true",
        help="Strip the shared baseline prefix from each update capture before writing output_chunks",
    )
    parser.add_argument(
        "--strip-shared-suffix",
        action="store_true",
        help="Strip the shared baseline suffix from each update capture after prefix stripping",
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
    raw_output_chunks = [read_text(Path(path)) for path in args.update_files]
    if args.strip_baseline_prefix:
        output_chunks = []
        for idx, chunk in enumerate(raw_output_chunks, start=1):
            prefix_len = trimmed_prefix_len(baseline, chunk)
            trimmed = chunk[prefix_len:]
            if args.strip_shared_suffix:
                baseline_tail = baseline[prefix_len:]
                suffix_len = trimmed_suffix_len(baseline_tail, trimmed)
                if suffix_len > 0:
                    trimmed = trimmed[:-suffix_len]
            if trimmed == "":
                parser.error(
                    f"update chunk {idx} became empty after shared prefix/suffix stripping; "
                    "capture a later update, disable stripping, or use a different staged input shape"
                )
            output_chunks.append(trimmed)
    else:
        for idx, chunk in enumerate(raw_output_chunks, start=1):
            if chunk == "":
                parser.error(
                    f"update chunk {idx} is empty; capture a later update or adjust checkpoint timing before authoring a redraw fixture"
                )
        output_chunks = raw_output_chunks

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

    if args.observed_file:
        observed = read_json(Path(args.observed_file))
        fixture["expected_dirty"] = observed["dirty"]
        fixture["expected_damage"] = observed["damage"]
        if observed.get("viewport_shift_rows") is not None:
            fixture["expected_viewport_shift_rows"] = observed["viewport_shift_rows"]
        if observed.get("viewport_shift_exposed_only") is not None:
            fixture["expected_viewport_shift_exposed_only"] = observed["viewport_shift_exposed_only"]

    fixture_path.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
    vt_path.write_text("", encoding="utf-8")

    print(f"wrote {fixture_path}")
    print(f"wrote {vt_path}")
    print("next:")
    if args.observed_file:
        print(f"  1. review expected redraw fields in {fixture_path.name}")
        print(f"  2. run: zig build test-terminal-replay -- --fixture {args.name} --update-goldens")
    else:
        print(f"  1. set expected_damage in {fixture_path.name}")
        print(f"  2. run: zig build test-terminal-replay -- --fixture {args.name} --update-goldens")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
