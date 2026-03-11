#!/usr/bin/env python3
"""
Drive the redraw-capture workflow end-to-end:
- capture a baseline PTY session
- capture one or more update PTY sessions
- emit a harness_api fixture skeleton
- optionally populate expected redraw fields from the replay runner
"""

from __future__ import annotations

import argparse
import json
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture baseline/update PTY sessions and emit a redraw fixture skeleton.")
    parser.add_argument("--name", required=True, help="Fixture stem")
    parser.add_argument("--rows", required=True, type=int, help="Viewport rows")
    parser.add_argument("--cols", required=True, type=int, help="Viewport cols")
    parser.add_argument("--line-ending", default="lf", choices=("lf", "crlf", "cr"))
    parser.add_argument("--fixture-dir", default="fixtures/terminal")
    parser.add_argument("--capture-dir", default="/tmp/zide-redraw-captures")
    parser.add_argument(
        "--hydrate-observed",
        action="store_true",
        help="Run terminal replay after fixture generation and hydrate expected redraw fields from observed output",
    )
    parser.add_argument(
        "--update-goldens",
        action="store_true",
        help="After fixture generation/hydration, run terminal replay with --update-goldens for this fixture",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="After fixture generation/hydration, run terminal replay validation for this fixture",
    )
    parser.add_argument("--cwd", help="Optional working directory for all PTY capture phases")
    parser.add_argument(
        "--no-stdout",
        action="store_true",
        help="Do not mirror PTY output to the current stdout during capture",
    )
    parser.add_argument("--baseline-stdin-file")
    parser.add_argument(
        "--update-stdin-file",
        action="append",
        dest="update_stdin_files",
        default=[],
        help="Optional scripted stdin per update PTY capture; repeat to match update-count",
    )
    parser.add_argument("--baseline-cmd", nargs="+", help="Baseline command to run in the PTY")
    parser.add_argument(
        "--baseline-shell",
        help="Shell command string for the baseline PTY capture (alternative to --baseline-cmd)",
    )
    parser.add_argument(
        "--update-cmd",
        action="append",
        nargs="+",
        help="Update command to run in the PTY; repeat for multiple update chunks",
    )
    parser.add_argument(
        "--update-shell",
        action="append",
        default=[],
        help="Shell command string for an update PTY capture; repeat for multiple update chunks",
    )
    args = parser.parse_args()
    if bool(args.baseline_cmd) == bool(args.baseline_shell):
        raise SystemExit("choose exactly one of --baseline-cmd or --baseline-shell")
    if not args.update_cmd and not args.update_shell:
        raise SystemExit("provide at least one --update-cmd or --update-shell")
    return args


def run_capture(
    output_file: Path,
    stdin_file: str | None,
    cmd: list[str],
    cwd: str | None,
    no_stdout: bool,
) -> None:
    argv = [
        sys.executable,
        "tools/terminal_capture_pty.py",
        "--output-file",
        str(output_file),
    ]
    if cwd:
        argv.extend(["--cwd", cwd])
    if no_stdout:
        argv.append("--no-stdout")
    if stdin_file:
        argv.extend(["--stdin-file", stdin_file])
    argv.extend(["--", *cmd])
    subprocess.run(argv, check=True)


def main() -> int:
    args = parse_args()
    if args.hydrate_observed and Path(args.fixture_dir) != Path("fixtures/terminal"):
        raise SystemExit("--hydrate-observed currently requires --fixture-dir fixtures/terminal")
    if (args.update_goldens or args.validate) and Path(args.fixture_dir) != Path("fixtures/terminal"):
        raise SystemExit("--update-goldens/--validate currently require --fixture-dir fixtures/terminal")

    update_cmds = list(args.update_cmd or [])
    update_cmds.extend([["bash", "-lc", cmd] for cmd in args.update_shell])
    baseline_cmd = args.baseline_cmd or ["bash", "-lc", args.baseline_shell]

    if args.update_stdin_files and len(args.update_stdin_files) not in (0, len(update_cmds)):
        raise SystemExit("--update-stdin-file count must be zero or match --update-cmd count")

    capture_dir = Path(args.capture_dir) / args.name
    if capture_dir.exists():
        shutil.rmtree(capture_dir)
    capture_dir.mkdir(parents=True, exist_ok=True)

    baseline_file = capture_dir / "baseline.txt"
    run_capture(baseline_file, args.baseline_stdin_file, baseline_cmd, args.cwd, args.no_stdout)

    update_files: list[Path] = []
    for idx, cmd in enumerate(update_cmds, start=1):
        update_file = capture_dir / f"update_{idx}.txt"
        stdin_file = args.update_stdin_files[idx - 1] if idx - 1 < len(args.update_stdin_files) else None
        run_capture(update_file, stdin_file, cmd, args.cwd, args.no_stdout)
        update_files.append(update_file)

    manifest = {
        "name": args.name,
        "rows": args.rows,
        "cols": args.cols,
        "line_ending": args.line_ending,
        "cwd": args.cwd,
        "no_stdout": args.no_stdout,
        "baseline": {
            "cmd": baseline_cmd,
            "stdin_file": args.baseline_stdin_file,
            "output_file": str(baseline_file),
        },
        "updates": [
            {
                "cmd": cmd,
                "stdin_file": args.update_stdin_files[idx] if idx < len(args.update_stdin_files) else None,
                "output_file": str(update_file),
            }
            for idx, (cmd, update_file) in enumerate(zip(update_cmds, update_files))
        ],
    }
    manifest_path = capture_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    argv = [
        sys.executable,
        "tools/terminal_make_redraw_fixture.py",
        "--name",
        args.name,
        "--rows",
        str(args.rows),
        "--cols",
        str(args.cols),
        "--line-ending",
        args.line_ending,
        "--fixture-dir",
        args.fixture_dir,
        "--baseline-file",
        str(baseline_file),
    ]
    for update_file in update_files:
        argv.extend(["--update-file", str(update_file)])
    subprocess.run(argv, check=True)

    if args.hydrate_observed:
        observed_file = capture_dir / "observed.json"
        subprocess.run(
            [
                "zig",
                "build",
                "test-terminal-replay",
                "--",
                "--fixture",
                args.name,
                "--observed-file",
                str(observed_file),
            ],
            check=True,
        )
        subprocess.run(
            [
                sys.executable,
                "tools/terminal_make_redraw_fixture.py",
                "--manifest-file",
                str(manifest_path),
                "--fixture-dir",
                args.fixture_dir,
                "--observed-file",
                str(observed_file),
            ],
            check=True,
        )

    if args.update_goldens:
        subprocess.run(
            [
                "zig",
                "build",
                "test-terminal-replay",
                "--",
                "--fixture",
                args.name,
                "--update-goldens",
            ],
            check=True,
        )

    if args.validate:
        subprocess.run(
            [
                "zig",
                "build",
                "test-terminal-replay",
                "--",
                "--fixture",
                args.name,
            ],
            check=True,
        )

    print(f"captures stored in {capture_dir}")
    print(f"manifest written to {manifest_path}")
    if args.hydrate_observed:
        print(f"observed redraw state written to {capture_dir / 'observed.json'}")
    if args.update_goldens:
        print(f"golden updated for fixture {args.name}")
    if args.validate:
        print(f"validated fixture {args.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
