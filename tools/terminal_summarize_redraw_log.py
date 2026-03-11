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


def find_latest_perf(lines: list[str], skip_reasons: set[str]) -> dict[str, str] | None:
    for line in reversed(lines):
        match = LOG_LINE_RE.match(line)
        if not match or match.group("tag") != "terminal.ui.perf":
            continue
        record = {
            "timestamp": match.group("ts"),
            "level": match.group("level"),
            "message": match.group("msg"),
        }
        fields = parse_fields(record["message"])
        reason = fields.get("full_dirty_reason")
        if reason is not None and reason in skip_reasons:
            continue
        return record
    return None


def parse_latest_pair(lines: list[str], skip_reasons: set[str]) -> tuple[dict[str, str] | None, dict[str, str] | None]:
    latest_perf = find_latest_perf(lines, skip_reasons)
    if latest_perf is None and not skip_reasons:
        latest_perf = parse_latest(lines, "terminal.ui.perf")

    latest_redraw: dict[str, str] | None = None
    if latest_perf is not None:
        for line in reversed(lines):
            match = LOG_LINE_RE.match(line)
            if not match or match.group("tag") != "terminal.ui.redraw":
                continue
            if match.group("ts") > latest_perf["timestamp"]:
                continue
            candidate = {
                "timestamp": match.group("ts"),
                "level": match.group("level"),
                "message": match.group("msg"),
            }
            if "partial_plan " in candidate["message"]:
                latest_redraw = candidate
                break
            if latest_redraw is None:
                latest_redraw = candidate
    return latest_perf, latest_redraw


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-file", default="zide.log", help="Path to zide.log")
    parser.add_argument("--tail-lines", type=int, default=2000, help="How many trailing log lines to inspect")
    parser.add_argument("--json", action="store_true", help="Emit parsed output as JSON")
    parser.add_argument(
        "--skip-full-dirty-reason",
        action="append",
        default=[],
        help="Ignore perf lines with these full_dirty_reason values",
    )
    parser.add_argument(
        "--interesting",
        action="store_true",
        help="Shorthand for skipping common lifecycle churn (init, alt_enter, alt_exit)",
    )
    args = parser.parse_args()

    log_path = pathlib.Path(args.log_file)
    if not log_path.exists():
        print(f"error: log file not found: {log_path}", file=sys.stderr)
        return 1

    lines = tail_lines(log_path, args.tail_lines)
    skip_reasons = set(args.skip_full_dirty_reason)
    if args.interesting:
        skip_reasons.update({"init", "alt_enter", "alt_exit"})
    perf, redraw = parse_latest_pair(lines, skip_reasons)
    if perf is None and skip_reasons:
        print(
            "no interesting terminal.ui.perf entries found after skipping "
            + ", ".join(sorted(skip_reasons)),
            file=sys.stderr,
        )
        return 1

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
                f"current_reason={perf_fields.get('current_reason', '?')} "
                f"damage_rows={perf_fields.get('damage_rows', '?')} "
                f"damage_cols={perf_fields.get('damage_cols', '?')} "
                f"plan_rows={perf_fields.get('plan_rows', '?')} "
                f"plan_row_span={perf_fields.get('plan_row_span', '?')} "
                f"plan_col_span={perf_fields.get('plan_col_span', '?')} "
                f"shift_rows={perf_fields.get('shift_rows', '?')} "
                f"shift_exposed_only={perf_fields.get('shift_exposed_only', '?')}"
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
