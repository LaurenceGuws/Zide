#!/usr/bin/env python3
"""Run Android local naming gate and compile check."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    return subprocess.run(command, cwd=ROOT, check=False).returncode


def main() -> int:
    steps = [
        [str(ROOT / "ops" / "lint_android_naming_all.py")],
        [
            str(ROOT / "android" / "terminal-host" / "gradlew"),
            "-p",
            str(ROOT / "android" / "terminal-host"),
            ":app:compileReleaseJavaWithJavac",
        ],
    ]
    for step in steps:
        rc = run(step)
        if rc != 0:
            return rc
    print("android-naming-gate: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
