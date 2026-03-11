#!/usr/bin/env python3
"""
Run a command inside a PTY and capture the raw terminal output bytes.

This is intended to support replay-fixture authoring for terminal redraw bugs:
- capture one baseline run or phase
- capture one or more update phases
- then turn those bytes into a harness_api fixture with terminal_make_redraw_fixture.py
"""

from __future__ import annotations

import argparse
import os
import pty
import select
import shlex
import signal
import subprocess
import sys
import termios
import tty
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture raw PTY output from a terminal command.")
    parser.add_argument("--output-file", required=True, help="Path to write raw PTY output bytes")
    parser.add_argument(
        "--stdin-file",
        help="Optional file whose bytes are replayed into the PTY stdin before live interactive forwarding",
    )
    parser.add_argument(
        "--no-stdout",
        action="store_true",
        help="Do not mirror child PTY output to the current stdout",
    )
    parser.add_argument(
        "--cwd",
        help="Optional working directory for the child command",
    )
    parser.add_argument(
        "cmd",
        nargs=argparse.REMAINDER,
        help="Command to execute after '--', or as remaining args",
    )
    args = parser.parse_args()
    if not args.cmd:
        parser.error("missing command; pass it after '--'")
    if args.cmd and args.cmd[0] == "--":
        args.cmd = args.cmd[1:]
    return args


def write_all(fd: int, data: bytes) -> None:
    offset = 0
    while offset < len(data):
        written = os.write(fd, data[offset:])
        offset += written


def main() -> int:
    args = parse_args()
    output_path = Path(args.output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    scripted_stdin = b""
    if args.stdin_file:
        scripted_stdin = Path(args.stdin_file).read_bytes()

    master_fd, slave_fd = pty.openpty()
    try:
        proc = subprocess.Popen(
            args.cmd,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            cwd=args.cwd,
            start_new_session=True,
        )
    finally:
        os.close(slave_fd)

    old_tty = None
    interactive_fd = None
    if sys.stdin.isatty():
        interactive_fd = sys.stdin.fileno()
        old_tty = termios.tcgetattr(interactive_fd)
        tty.setraw(interactive_fd)

    captured = bytearray()
    pending_script = memoryview(scripted_stdin)

    def restore_tty() -> None:
        nonlocal old_tty, interactive_fd
        if old_tty is not None and interactive_fd is not None:
            termios.tcsetattr(interactive_fd, termios.TCSADRAIN, old_tty)
            old_tty = None

    try:
        while True:
            read_fds = [master_fd]
            if interactive_fd is not None:
                read_fds.append(interactive_fd)

            write_fds = [master_fd] if pending_script else []
            ready_r, ready_w, _ = select.select(read_fds, write_fds, [], 0.05)

            if pending_script and master_fd in ready_w:
                chunk = pending_script[:4096].tobytes()
                write_all(master_fd, chunk)
                pending_script = pending_script[len(chunk) :]

            if master_fd in ready_r:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    data = b""
                if data:
                    captured.extend(data)
                    if not args.no_stdout:
                        os.write(sys.stdout.fileno(), data)
                elif proc.poll() is not None:
                    break

            if interactive_fd is not None and interactive_fd in ready_r:
                data = os.read(interactive_fd, 4096)
                if data:
                    if data == b"\x03":
                        proc.send_signal(signal.SIGINT)
                    write_all(master_fd, data)

            if proc.poll() is not None and not pending_script:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    data = b""
                if data:
                    captured.extend(data)
                    if not args.no_stdout:
                        os.write(sys.stdout.fileno(), data)
                else:
                    break
    finally:
        restore_tty()
        os.close(master_fd)

    output_path.write_bytes(bytes(captured))
    if proc.returncode is None:
        proc.wait()

    print(
        f"\nCaptured {len(captured)} bytes to {output_path} from: {' '.join(shlex.quote(part) for part in args.cmd)}",
        file=sys.stderr,
    )
    return proc.returncode or 0


if __name__ == "__main__":
    raise SystemExit(main())
