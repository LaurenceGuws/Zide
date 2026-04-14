#!/usr/bin/env python3
"""Run Android naming lints as one local gate."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(script_name: str) -> int:
    script_path = ROOT / "ops" / script_name
    result = subprocess.run([str(script_path)], cwd=ROOT, check=False)
    return result.returncode


def main() -> int:
    rc_java = run("lint_android_java_events.py")
    rc_zig = run("lint_android_zig_naming.py")
    if rc_java != 0 or rc_zig != 0:
        return 1
    print("android-naming-lint: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
