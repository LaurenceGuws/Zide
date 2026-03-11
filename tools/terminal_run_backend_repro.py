#!/usr/bin/env python3
"""Run a terminal-mode repro command and summarize redraw logs."""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default="./zig-out/bin/zide-terminal", help="Path to zide-terminal")
    parser.add_argument("--cwd", help="Working directory for the child command")
    parser.add_argument("--shell", help="Explicit shell/program override")
    parser.add_argument("--command", required=True, help="Terminal child command to run")
    parser.add_argument("--log-file", default="zide.log", help="Log file to summarize")
    parser.add_argument("--count", type=int, default=5, help="How many interesting redraw frames to print")
    parser.add_argument("--tail-lines", type=int, default=4000, help="How many log lines to inspect")
    parser.add_argument("--timeout-seconds", type=float, default=30.0, help="Kill the terminal run if it exceeds this timeout")
    parser.add_argument("--keep-log", action="store_true", help="Do not delete the previous log before running")
    args = parser.parse_args()

    log_path = pathlib.Path(args.log_file)
    if not args.keep_log and log_path.exists():
        log_path.unlink()

    cmd = [args.binary]
    if args.cwd:
        cmd.extend(["--cwd", args.cwd])
    if args.shell:
        cmd.extend(["--shell", args.shell])
    cmd.extend(["--command", args.command, "--close-on-child-exit"])

    try:
        completed = subprocess.run(cmd, check=False, timeout=args.timeout_seconds)
    except subprocess.TimeoutExpired:
        print(
            f"zide-terminal timed out after {args.timeout_seconds:.1f}s while running {args.command!r}",
            file=sys.stderr,
        )
        return 124
    if completed.returncode != 0:
        print(f"zide-terminal exited with code {completed.returncode}", file=sys.stderr)
        return completed.returncode

    summary_cmd = [
        sys.executable,
        "tools/terminal_summarize_redraw_log.py",
        "--log-file",
        args.log_file,
        "--interesting",
        "--count",
        str(args.count),
        "--tail-lines",
        str(args.tail_lines),
    ]
    return subprocess.run(summary_cmd, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
