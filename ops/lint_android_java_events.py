#!/usr/bin/env python3
"""Fail-fast lint for Android Java appendEvent key grammar."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
JAVA_ROOT = ROOT / "android" / "terminal-host" / "app" / "src" / "main" / "java" / "uk" / "laurencegouws" / "terminal"
APPEND_EVENT_RE = re.compile(r'appendEvent\("([^"]+)"')
UPDATE_STATUS_RE = re.compile(r'updateStatus\("([^"]+)"\)')
KEY_RE = re.compile(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}")
FORBIDDEN_TERMINAL_NATIVE_SHELL = re.compile(r"\bnative[A-Za-z0-9_]*Shell[A-Za-z0-9_]*Bridge\b")


def main() -> int:
    violations: list[str] = []
    for file_path in sorted(JAVA_ROOT.rglob("*.java")):
        lines = file_path.read_text(encoding="utf-8").splitlines()
        if file_path.name == "TerminalNativeBridge.java":
            for line_no, line in enumerate(lines, start=1):
                match_forbidden = FORBIDDEN_TERMINAL_NATIVE_SHELL.search(line)
                if match_forbidden:
                    rel = file_path.relative_to(ROOT)
                    violations.append(
                        f"{rel}:{line_no}: forbidden JNI symbol token '{match_forbidden.group(0)}'"
                    )
        for line_no, line in enumerate(lines, start=1):
            match = APPEND_EVENT_RE.search(line)
            if match:
                event = match.group(1)
                token = event.split(" ", 1)[0]
                if not KEY_RE.fullmatch(token):
                    rel = file_path.relative_to(ROOT)
                    violations.append(f"{rel}:{line_no}: invalid event key '{token}'")

            update_match = UPDATE_STATUS_RE.search(line)
            if update_match:
                status_key = update_match.group(1)
                if not KEY_RE.fullmatch(status_key):
                    rel = file_path.relative_to(ROOT)
                    violations.append(f"{rel}:{line_no}: invalid status key '{status_key}'")

    if violations:
        print("android-java-events-lint: invalid appendEvent keys found", file=sys.stderr)
        for item in violations:
            print(item, file=sys.stderr)
        return 1

    print("android-java-events-lint: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
