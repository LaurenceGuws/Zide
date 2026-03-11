#!/usr/bin/env python3
"""Summarize recent terminal redraw log lines from zide.log."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys


LOG_LINE_RE = re.compile(r"^\[(?P<ts>[^\]]+)\]\[\+[^\]]+\]\[(?P<level>[^\]]+)\]\[(?P<tag>[^\]]+)\] (?P<msg>.*)$")
FIELD_RE = re.compile(r"(?P<key>[a-zA-Z0-9_]+)=(?P<value>[^ ]+)")


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


def parse_fields(message: str) -> dict[str, str]:
    return {match.group("key"): match.group("value") for match in FIELD_RE.finditer(message)}


def parse_latest_pair(lines: list[str]) -> tuple[dict[str, str] | None, dict[str, str] | None]:
    latest_perf = parse_latest(lines, "terminal.ui.perf")
    latest_redraw = parse_latest(lines, "terminal.ui.redraw")
    if latest_perf is None or latest_redraw is None:
        return latest_perf, latest_redraw

    # Prefer the latest redraw at or before the latest perf, so the pair stays
    # temporally coherent during manual investigation.
    if latest_redraw["timestamp"] <= latest_perf["timestamp"]:
        return latest_perf, latest_redraw

    for line in reversed(lines):
        match = LOG_LINE_RE.match(line)
        if not match or match.group("tag") != "terminal.ui.redraw":
            continue
        if match.group("ts") <= latest_perf["timestamp"]:
            latest_redraw = {
                "timestamp": match.group("ts"),
                "level": match.group("level"),
                "message": match.group("msg"),
            }
            break
    return latest_perf, latest_redraw


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-file", default="zide.log", help="Path to zide.log")
    parser.add_argument("--tail-lines", type=int, default=2000, help="How many trailing log lines to inspect")
    parser.add_argument("--json", action="store_true", help="Emit parsed output as JSON")
    args = parser.parse_args()

    log_path = pathlib.Path(args.log_file)
    if not log_path.exists():
        print(f"error: log file not found: {log_path}", file=sys.stderr)
        return 1

    lines = tail_lines(log_path, args.tail_lines)
    perf, redraw = parse_latest_pair(lines)

    if perf is None and redraw is None:
        print("no terminal.ui.perf or terminal.ui.redraw entries found", file=sys.stderr)
        return 1

    if args.json:
        payload = {}
        if perf is not None:
            payload["perf"] = perf | {"fields": parse_fields(perf["message"])}
        if redraw is not None:
            payload["redraw"] = redraw | {"fields": parse_fields(redraw["message"])}
        json.dump(payload, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0

    if perf is not None:
        perf_fields = parse_fields(perf["message"])
        print(f"perf[{perf['timestamp']}]: {perf['message']}")
        if perf_fields:
            print(
                "  parsed: "
                f"dirty={perf_fields.get('dirty', '?')} "
                f"damage_rows={perf_fields.get('damage_rows', '?')} "
                f"damage_cols={perf_fields.get('damage_cols', '?')} "
                f"plan_rows={perf_fields.get('plan_rows', '?')} "
                f"plan_row_span={perf_fields.get('plan_row_span', '?')} "
                f"plan_col_span={perf_fields.get('plan_col_span', '?')}"
            )
    if redraw is not None:
        redraw_fields = parse_fields(redraw["message"])
        print(f"redraw[{redraw['timestamp']}]: {redraw['message']}")
        if redraw_fields:
            spans = redraw_fields.get("spans", "?")
            print(f"  parsed: spans={spans}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
