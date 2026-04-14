#!/usr/bin/env python3
"""Fail-fast lint for Android Java appendEvent key grammar."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
JAVA_ROOT = ROOT / "android" / "terminal-host" / "app" / "src" / "main" / "java" / "uk" / "laurencegouws" / "terminal"
APPEND_EVENT_RE = re.compile(r'appendEvent\("([^"]+)"')
KEY_RE = re.compile(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}")


def main() -> int:
    violations: list[str] = []
    for file_path in sorted(JAVA_ROOT.rglob("*.java")):
        lines = file_path.read_text(encoding="utf-8").splitlines()
        for line_no, line in enumerate(lines, start=1):
            match = APPEND_EVENT_RE.search(line)
            if not match:
                continue
            event = match.group(1)
            token = event.split(" ", 1)[0]
            if not KEY_RE.fullmatch(token):
                rel = file_path.relative_to(ROOT)
                violations.append(f"{rel}:{line_no}: invalid event key '{token}'")

    if violations:
        print("android-java-events-lint: invalid appendEvent keys found", file=sys.stderr)
        for item in violations:
            print(item, file=sys.stderr)
        return 1

    print("android-java-events-lint: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
