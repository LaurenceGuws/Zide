#!/usr/bin/env python3
"""Summarize recent terminal redraw log lines from zide.log.

This is intentionally small and text-oriented. It does not try to fully parse
every field; it extracts the latest terminal.ui.perf and terminal.ui.redraw
records so redraw investigations can compare backend damage against live widget
plan shape quickly.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


LOG_LINE_RE = re.compile(r"^\[(?P<ts>[^\]]+)\]\[\+[^\]]+\]\[(?P<level>[^\]]+)\]\[(?P<tag>[^\]]+)\] (?P<msg>.*)$")


def tail_lines(path: pathlib.Path, limit: int) -> list[str]:
    data = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if limit <= 0:
        return data
    return data[-limit:]


def parse_latest(lines: list[str], tag: str) -> dict[str, str] | None:
    for line in reversed(lines):
        match = LOG_LINE_RE.match(line)
        if not match or match.group("tag") != tag:
            continue
        return {
            "timestamp": match.group("ts"),
            "level": match.group("level"),
            "message": match.group("msg"),
        }
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-file", default="zide.log", help="Path to zide.log")
    parser.add_argument("--tail-lines", type=int, default=2000, help="How many trailing log lines to inspect")
    args = parser.parse_args()

    log_path = pathlib.Path(args.log_file)
    if not log_path.exists():
        print(f"error: log file not found: {log_path}", file=sys.stderr)
        return 1

    lines = tail_lines(log_path, args.tail_lines)
    perf = parse_latest(lines, "terminal.ui.perf")
    redraw = parse_latest(lines, "terminal.ui.redraw")

    if perf is None and redraw is None:
        print("no terminal.ui.perf or terminal.ui.redraw entries found", file=sys.stderr)
        return 1

    if perf is not None:
        print(f"perf[{perf['timestamp']}]: {perf['message']}")
    if redraw is not None:
        print(f"redraw[{redraw['timestamp']}]: {redraw['message']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
