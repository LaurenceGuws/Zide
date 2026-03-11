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
        "--strip-baseline-prefix",
        action="store_true",
        help="Strip the shared baseline prefix from each update capture when generating output_chunks",
    )
    parser.add_argument(
        "--strip-shared-suffix",
        action="store_true",
        help="Strip the shared baseline suffix from each update capture after prefix stripping",
    )
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
    parser.add_argument("--baseline-stdin-script")
    parser.add_argument("--checkpoint-quiet-ms", type=int, default=120)
    parser.add_argument(
        "--update-stdin-file",
        action="append",
        dest="update_stdin_files",
        default=[],
        help="Optional scripted stdin per update PTY capture; repeat to match update-count",
    )
    parser.add_argument(
        "--update-stdin-script",
        action="append",
        dest="update_stdin_scripts",
        default=[],
        help="Optional scripted stdin action file per update PTY capture; repeat to match update-count",
    )
    parser.add_argument("--single-session-shell", help="Run one long-lived PTY session and split it into baseline/update checkpoints.")
    parser.add_argument("--single-session-cmd", nargs="+", help="Single-session PTY command; alternative to --single-session-shell.")
    parser.add_argument("--single-session-stdin-file")
    parser.add_argument("--single-session-stdin-script")
    parser.add_argument("--single-session-baseline-at", type=float, help="Seconds to flush the baseline checkpoint in single-session mode.")
    parser.add_argument(
        "--single-session-update-at",
        action="append",
        type=float,
        default=[],
        help="Seconds to flush an update checkpoint in single-session mode; repeat for multiple chunks.",
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
    single_session = bool(args.single_session_shell) or bool(args.single_session_cmd)
    split_sessions = bool(args.baseline_cmd) or bool(args.baseline_shell) or bool(args.update_cmd) or bool(args.update_shell)
    if single_session and split_sessions:
        raise SystemExit("choose either single-session mode or split baseline/update mode, not both")
    if not single_session and not split_sessions:
        raise SystemExit("provide either single-session args or baseline/update args")
    if single_session:
        if bool(args.single_session_shell) == bool(args.single_session_cmd):
            raise SystemExit("choose exactly one of --single-session-shell or --single-session-cmd")
        if args.single_session_baseline_at is None or not args.single_session_update_at:
            raise SystemExit("single-session mode requires --single-session-baseline-at and at least one --single-session-update-at")
        return args
    if bool(args.baseline_cmd) == bool(args.baseline_shell):
        raise SystemExit("choose exactly one of --baseline-cmd or --baseline-shell")
    if not args.update_cmd and not args.update_shell:
        raise SystemExit("provide at least one --update-cmd or --update-shell")
    return args


def run_capture(
    output_file: Path,
    stdin_file: str | None,
    stdin_script: str | None,
    cmd: list[str],
    cwd: str | None,
    no_stdout: bool,
    checkpoint_quiet_ms: int,
    checkpoints: list[tuple[float, Path]] | None = None,
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
    argv.extend(["--checkpoint-quiet-ms", str(checkpoint_quiet_ms)])
    if stdin_file:
        argv.extend(["--stdin-file", stdin_file])
    if stdin_script:
        argv.extend(["--stdin-script", stdin_script])
    if checkpoints:
        for delay, checkpoint_file in checkpoints:
            argv.extend(["--checkpoint", f"{delay}:{checkpoint_file}"])
    argv.extend(["--", *cmd])
    subprocess.run(argv, check=True)


def main() -> int:
    args = parse_args()
    if args.hydrate_observed and Path(args.fixture_dir) != Path("fixtures/terminal"):
        raise SystemExit("--hydrate-observed currently requires --fixture-dir fixtures/terminal")
    if (args.update_goldens or args.validate) and Path(args.fixture_dir) != Path("fixtures/terminal"):
        raise SystemExit("--update-goldens/--validate currently require --fixture-dir fixtures/terminal")

    capture_dir = Path(args.capture_dir) / args.name
    if capture_dir.exists():
        shutil.rmtree(capture_dir)
    capture_dir.mkdir(parents=True, exist_ok=True)

    baseline_file = capture_dir / "baseline.txt"
    update_files: list[Path] = []
    manifest: dict[str, object]

    if args.single_session_shell or args.single_session_cmd:
        session_cmd = args.single_session_cmd or ["bash", "-lc", args.single_session_shell]
        full_output_file = capture_dir / "full.txt"
        checkpoints = [(args.single_session_baseline_at, baseline_file)]
        for idx, delay in enumerate(args.single_session_update_at, start=1):
            update_file = capture_dir / f"update_{idx}.txt"
            checkpoints.append((delay, update_file))
            update_files.append(update_file)
        run_capture(
            full_output_file,
            args.single_session_stdin_file,
            args.single_session_stdin_script,
            session_cmd,
            args.cwd,
            args.no_stdout,
            args.checkpoint_quiet_ms,
            checkpoints=checkpoints,
        )
        manifest = {
            "name": args.name,
            "rows": args.rows,
            "cols": args.cols,
            "line_ending": args.line_ending,
            "cwd": args.cwd,
            "no_stdout": args.no_stdout,
            "capture_mode": "single_session",
            "single_session": {
                "cmd": session_cmd,
                "stdin_file": args.single_session_stdin_file,
                "stdin_script": args.single_session_stdin_script,
                "output_file": str(full_output_file),
                "baseline_at": args.single_session_baseline_at,
                "update_at": args.single_session_update_at,
                "checkpoint_quiet_ms": args.checkpoint_quiet_ms,
            },
            "baseline": {"output_file": str(baseline_file)},
            "updates": [{"output_file": str(update_file)} for update_file in update_files],
        }
    else:
        update_cmds = list(args.update_cmd or [])
        update_cmds.extend([["bash", "-lc", cmd] for cmd in args.update_shell])
        baseline_cmd = args.baseline_cmd or ["bash", "-lc", args.baseline_shell]

        if args.update_stdin_files and len(args.update_stdin_files) not in (0, len(update_cmds)):
            raise SystemExit("--update-stdin-file count must be zero or match --update-cmd count")
        if args.update_stdin_scripts and len(args.update_stdin_scripts) not in (0, len(update_cmds)):
            raise SystemExit("--update-stdin-script count must be zero or match --update-cmd count")

        run_capture(
            baseline_file,
            args.baseline_stdin_file,
            args.baseline_stdin_script,
            baseline_cmd,
            args.cwd,
            args.no_stdout,
            args.checkpoint_quiet_ms,
        )

        for idx, cmd in enumerate(update_cmds, start=1):
            update_file = capture_dir / f"update_{idx}.txt"
            stdin_file = args.update_stdin_files[idx - 1] if idx - 1 < len(args.update_stdin_files) else None
            stdin_script = (
                args.update_stdin_scripts[idx - 1] if idx - 1 < len(args.update_stdin_scripts) else None
            )
            run_capture(
                update_file,
                stdin_file,
                stdin_script,
                cmd,
                args.cwd,
                args.no_stdout,
                args.checkpoint_quiet_ms,
            )
            update_files.append(update_file)

        manifest = {
            "name": args.name,
            "rows": args.rows,
            "cols": args.cols,
            "line_ending": args.line_ending,
            "cwd": args.cwd,
            "no_stdout": args.no_stdout,
            "capture_mode": "split_sessions",
            "baseline": {
                "cmd": baseline_cmd,
                "stdin_file": args.baseline_stdin_file,
                "stdin_script": args.baseline_stdin_script,
                "output_file": str(baseline_file),
            },
            "updates": [
                {
                    "cmd": cmd,
                    "stdin_file": args.update_stdin_files[idx] if idx < len(args.update_stdin_files) else None,
                    "stdin_script": args.update_stdin_scripts[idx] if idx < len(args.update_stdin_scripts) else None,
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
    if args.strip_baseline_prefix:
        argv.append("--strip-baseline-prefix")
    if args.strip_shared_suffix:
        argv.append("--strip-shared-suffix")
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
                "--observe-only",
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
            ]
            + (["--strip-baseline-prefix"] if args.strip_baseline_prefix else [])
            + (["--strip-shared-suffix"] if args.strip_shared_suffix else []),
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
