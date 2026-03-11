#!/usr/bin/env python3
"""Run a command while injecting timed input bytes into its controlling TTY."""

from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import sys
import threading
import time


def parse_text_payload(value: str) -> bytes:
    return value.encode("utf-8")


def parse_hex_payload(value: str) -> bytes:
    return bytes.fromhex(value)


def load_payload(path: str) -> bytes:
    return pathlib.Path(path).read_bytes()


def build_step(step: str) -> tuple[float, bytes]:
    try:
        delay_raw, kind, payload_raw = step.split(":", 2)
    except ValueError as err:
        raise SystemExit(f"invalid --step value {step!r}; expected <seconds>:<text|hex|file>:<payload>") from err

    try:
        delay = float(delay_raw)
    except ValueError as err:
        raise SystemExit(f"invalid step delay {delay_raw!r}") from err

    if delay < 0:
        raise SystemExit(f"step delay must be >= 0, got {delay}")

    if kind == "text":
        payload = parse_text_payload(payload_raw)
    elif kind == "hex":
        payload = parse_hex_payload(payload_raw)
    elif kind == "file":
        payload = load_payload(payload_raw)
    else:
        raise SystemExit(f"invalid step payload kind {kind!r}; expected text, hex, or file")

    return delay, payload


def write_steps(tty_path: str, steps: list[tuple[float, bytes]]) -> None:
    start = time.monotonic()
    with open(tty_path, "wb", buffering=0) as tty:
        for delay, payload in steps:
            remaining = delay - (time.monotonic() - start)
            if remaining > 0:
                time.sleep(remaining)
            tty.write(payload)
            tty.flush()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--step",
        action="append",
        default=[],
        help="Timed TTY input step: <seconds>:<text|hex|file>:<payload>",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run after '--'")
    args = parser.parse_args()

    if not args.step:
        parser.error("at least one --step is required")
    if not args.command or args.command[0] != "--" or len(args.command) < 2:
        parser.error("command must be provided after '--'")

    tty_path = os.ttyname(sys.stdin.fileno())
    steps = [build_step(step) for step in args.step]
    command = args.command[1:]

    worker = threading.Thread(target=write_steps, args=(tty_path, steps), daemon=True)
    worker.start()
    completed = subprocess.run(command, check=False)
    worker.join(timeout=1.0)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
