#!/usr/bin/env python3
"""Run a terminal-mode repro command and summarize redraw logs."""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys


def run_summary(args: argparse.Namespace) -> int:
    summary_cmd = [
        sys.executable,
        "tools/terminal_summarize_redraw_log.py",
        "--log-file",
        args.log_file,
        "--interesting",
        "--empty-ok",
        "--count",
        str(args.count),
        "--select",
        args.select,
        "--tail-lines",
        str(args.tail_lines),
    ]
    summary_result = subprocess.run(summary_cmd, check=False)
    if args.summary_json_file:
        json_cmd = summary_cmd + ["--json"]
        json_result = subprocess.run(json_cmd, check=False, capture_output=True, text=True)
        if json_result.returncode != 0:
            sys.stderr.write(json_result.stderr)
            return json_result.returncode
        pathlib.Path(args.summary_json_file).write_text(json_result.stdout, encoding="utf-8")
    return summary_result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default="./zig-out/bin/zide-terminal", help="Path to zide-terminal")
    parser.add_argument("--rows", type=int, help="Fixed terminal row count for the repro run")
    parser.add_argument("--cols", type=int, help="Fixed terminal column count for the repro run")
    parser.add_argument("--cwd", help="Working directory for the child command")
    parser.add_argument("--shell", help="Explicit shell/program override")
    command_group = parser.add_mutually_exclusive_group(required=True)
    command_group.add_argument("--command", help="Terminal child command to run")
    command_group.add_argument("--command-file", help="Read the terminal child command from this file")
    parser.add_argument("--log-file", default="zide.log", help="Log file to summarize")
    parser.add_argument("--count", type=int, default=5, help="How many interesting redraw frames to print")
    parser.add_argument(
        "--select",
        choices=("latest", "max-damage-area", "max-plan-area", "max-dirty-rows"),
        default="latest",
        help="How to choose interesting redraw frames from the log",
    )
    parser.add_argument("--tail-lines", type=int, default=4000, help="How many log lines to inspect")
    parser.add_argument("--timeout-seconds", type=float, default=30.0, help="Kill the terminal run if it exceeds this timeout")
    parser.add_argument("--summary-json-file", help="Also write the parsed redraw summary as JSON to this path")
    parser.add_argument("--keep-log", action="store_true", help="Do not delete the previous log before running")
    args = parser.parse_args()

    log_path = pathlib.Path(args.log_file)
    if not args.keep_log and log_path.exists():
        log_path.unlink()

    command = args.command
    if args.command_file is not None:
        command = pathlib.Path(args.command_file).read_text(encoding="utf-8").strip()
    assert command is not None

    cmd = [args.binary]
    if args.rows is not None:
        cmd.extend(["--rows", str(args.rows)])
    if args.cols is not None:
        cmd.extend(["--cols", str(args.cols)])
    if args.cwd:
        cmd.extend(["--cwd", args.cwd])
    if args.shell:
        cmd.extend(["--shell", args.shell])
    cmd.extend(["--command", command, "--close-on-child-exit"])

    try:
        completed = subprocess.run(cmd, check=False, timeout=args.timeout_seconds)
    except subprocess.TimeoutExpired:
        print(
            f"zide-terminal timed out after {args.timeout_seconds:.1f}s while running {command!r}",
            file=sys.stderr,
        )
        run_summary(args)
        return 124
    if completed.returncode != 0:
        print(f"zide-terminal exited with code {completed.returncode}", file=sys.stderr)
        return completed.returncode

    return run_summary(args)


if __name__ == "__main__":
    raise SystemExit(main())
