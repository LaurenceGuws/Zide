#!/usr/bin/env python3
"""Fail-fast lint for Android Zig bridge forbidden naming terms."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]

TARGET_GLOBS = (
    "src/platform/android*.zig",
    "src/android_bridge_exports/*.zig",
)

FORBIDDEN_PATTERNS = (
    (r"^\s*(?:pub\s+)?fn\s+note[A-Z]\w*\s*\(", "event entrypoints must use on*"),
    (r"\bProbeStatus\b", "use RendererStatus"),
    (r"\bProbeState\b", "use RendererState"),
    (r"android_gles_probe", "use android_gles_surface_status"),
    (r"terminal_session_bootstrap", "use terminal_session_runtime_factory"),
    (r"\brestartShellSession\b", "use restartSession"),
    (r"\bcurrentShell[A-Z]\w*\b", "use concise runtime naming"),
)


def iter_targets() -> list[Path]:
    paths: list[Path] = []
    for pattern in TARGET_GLOBS:
        paths.extend(ROOT.glob(pattern))
    return sorted({path for path in paths if path.is_file()})


def main() -> int:
    violations: list[str] = []
    targets = iter_targets()
    for file_path in targets:
        text = file_path.read_text(encoding="utf-8")
        rel = file_path.relative_to(ROOT)
        for pattern, hint in FORBIDDEN_PATTERNS:
            regex = re.compile(pattern)
            for index, line in enumerate(text.splitlines(), start=1):
                if regex.search(line):
                    violations.append(f"{rel}:{index}: {hint}: {line.strip()}")

    if violations:
        print("android-zig-naming-lint: forbidden terms found", file=sys.stderr)
        for item in violations:
            print(item, file=sys.stderr)
        return 1

    print("android-zig-naming-lint: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
