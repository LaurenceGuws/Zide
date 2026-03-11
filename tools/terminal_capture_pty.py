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
import time
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
        "--stdin-step",
        action="append",
        default=[],
        help="Timed stdin injection as <seconds>:<file>; repeat for multiple steps",
    )
    parser.add_argument(
        "--checkpoint",
        action="append",
        default=[],
        help="Timed output checkpoint as <seconds>:<output-file>; writes bytes captured since the previous checkpoint",
    )
    parser.add_argument(
        "--checkpoint-quiet-ms",
        type=int,
        default=120,
        help="Idle time after a checkpoint becomes due before it flushes captured bytes (default: 120ms)",
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


def parse_timed_path(spec: str, what: str) -> tuple[float, str]:
    try:
        delay_text, path = spec.split(":", 1)
    except ValueError as exc:
        raise SystemExit(f"invalid {what} '{spec}'; expected <seconds>:<path>") from exc
    try:
        delay = float(delay_text)
    except ValueError as exc:
        raise SystemExit(f"invalid {what} delay '{delay_text}' in '{spec}'") from exc
    if delay < 0:
        raise SystemExit(f"invalid {what} delay '{delay_text}' in '{spec}'; must be >= 0")
    if not path:
        raise SystemExit(f"invalid {what} '{spec}'; missing path")
    return delay, path


def main() -> int:
    args = parse_args()
    output_path = Path(args.output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    scripted_stdin = b""
    if args.stdin_file:
        scripted_stdin = Path(args.stdin_file).read_bytes()

    stdin_steps: list[tuple[float, bytes]] = []
    for spec in args.stdin_step:
        delay, path = parse_timed_path(spec, "stdin step")
        stdin_steps.append((delay, Path(path).read_bytes()))
    stdin_steps.sort(key=lambda item: item[0])

    checkpoints: list[tuple[float, Path]] = []
    for spec in args.checkpoint:
        delay, path = parse_timed_path(spec, "checkpoint")
        checkpoint_path = Path(path)
        checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
        checkpoints.append((delay, checkpoint_path))
    checkpoints.sort(key=lambda item: item[0])

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
    step_index = 0
    checkpoint_index = 0
    checkpoint_start = 0
    started_at = time.monotonic()
    last_output_at = started_at
    checkpoint_quiet_seconds = args.checkpoint_quiet_ms / 1000.0

    def flush_due_checkpoints(final: bool = False) -> None:
        nonlocal checkpoint_index, checkpoint_start
        elapsed = time.monotonic() - started_at
        while checkpoint_index < len(checkpoints):
            delay, path = checkpoints[checkpoint_index]
            if not final and elapsed < delay:
                break
            if not final and (time.monotonic() - last_output_at) < checkpoint_quiet_seconds:
                break
            path.write_bytes(bytes(captured[checkpoint_start:]))
            checkpoint_start = len(captured)
            checkpoint_index += 1

    def restore_tty() -> None:
        nonlocal old_tty, interactive_fd
        if old_tty is not None and interactive_fd is not None:
            termios.tcsetattr(interactive_fd, termios.TCSADRAIN, old_tty)
            old_tty = None

    try:
        while True:
            flush_due_checkpoints()
            elapsed = time.monotonic() - started_at
            while step_index < len(stdin_steps) and elapsed >= stdin_steps[step_index][0]:
                delay, data = stdin_steps[step_index]
                _ = delay
                pending_script = memoryview(bytes(pending_script) + data)
                step_index += 1

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
                    last_output_at = time.monotonic()
                    flush_due_checkpoints()
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
                    last_output_at = time.monotonic()
                    flush_due_checkpoints()
                    if not args.no_stdout:
                        os.write(sys.stdout.fileno(), data)
                else:
                    break
    finally:
        restore_tty()
        os.close(master_fd)

    flush_due_checkpoints(final=True)
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
