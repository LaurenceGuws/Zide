#!/usr/bin/env python3
"""
Capture the real-config Neovim cursor-step redraw repro in one scripted session.

This wraps terminal_capture_redraw_fixture.py so the current plugin-heavy
cursor-step invalidation lane can be rerun without manual typing.
"""

from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", default="redraw_nvim_real_config_cursor_step_probe")
    parser.add_argument("--rows", type=int, default=16)
    parser.add_argument("--cols", type=int, default=100)
    parser.add_argument("--cwd", default="/home/home/personal/zide")
    parser.add_argument("--target-file", default="src/app_logger.zig")
    parser.add_argument(
        "--nvim-command",
        default="nvim",
        help="Command used to launch Neovim. Defaults to plain 'nvim' so the local dashboard/config loads.",
    )
    parser.add_argument(
        "--open-directly",
        action="store_true",
        help="Launch nvim on the target file directly instead of starting at the dashboard and sending :e.",
    )
    parser.add_argument(
        "--open-command",
        default=":e {target}\\r",
        help="Ex command sent from the dashboard/start screen. {target} is replaced with the absolute target path.",
    )
    parser.add_argument(
        "--jump-command",
        default="50%zz",
        help="Normal-mode command used after the file is open and LSP settles.",
    )
    parser.add_argument("--dashboard-settle-seconds", type=float, default=1.0)
    parser.add_argument("--lsp-settle-seconds", type=float, default=3.0)
    parser.add_argument("--baseline-settle-seconds", type=float, default=0.8)
    parser.add_argument("--step-key", default="j")
    parser.add_argument("--step-count", type=int, default=12)
    parser.add_argument(
        "--idle-update-seconds",
        type=float,
        default=1.35,
        help="When --step-count=0, capture one idle update this many seconds after the baseline.",
    )
    parser.add_argument(
        "--capture-step-start",
        type=int,
        default=6,
        help="1-based cursor-step index where update checkpoints start. Early cursor steps are often quiet.",
    )
    parser.add_argument(
        "--capture-each-step",
        action="store_true",
        help="Emit one update checkpoint per captured cursor step instead of one aggregate update chunk.",
    )
    parser.add_argument("--step-gap-seconds", type=float, default=1.0)
    parser.add_argument("--step-settle-seconds", type=float, default=0.35)
    parser.add_argument("--post-steps-settle-seconds", type=float, default=0.8)
    parser.add_argument("--quit-command", default="\\x1b:q!\\r")
    parser.add_argument("--checkpoint-quiet-ms", type=int, default=150)
    parser.add_argument("--capture-dir", default="/tmp/zide-redraw-captures")
    parser.add_argument("--fixture-dir", default="fixtures/terminal")
    parser.add_argument("--hydrate-observed", action="store_true")
    parser.add_argument("--update-goldens", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--no-stdout", action="store_true")
    return parser.parse_args()


def build_stdin_script(args: argparse.Namespace, target_path: Path) -> tuple[str, float, list[float], str]:
    lines: list[str] = []
    session_shell = args.nvim_command if not args.open_directly else f"{args.nvim_command} {shlex.quote(str(target_path))}"
    at = 0.0
    if not args.open_directly:
        at = args.dashboard_settle_seconds
        lines.append(f"{at:.2f} text {args.open_command.format(target=target_path)}")
    at += args.lsp_settle_seconds
    lines.append(f"{at:.2f} text {args.jump_command}")
    baseline_at = at + args.baseline_settle_seconds

    update_ats: list[float] = []
    at = baseline_at
    if args.step_count == 0:
        update_ats = [baseline_at + args.idle_update_seconds]
    for step_index in range(1, args.step_count + 1):
        at += args.step_gap_seconds
        lines.append(f"{at:.2f} text {args.step_key}")
        if step_index >= args.capture_step_start:
            capture_at = at + args.step_settle_seconds
            if args.capture_each_step:
                update_ats.append(capture_at)
            else:
                update_ats = [capture_at]

    quit_at = update_ats[-1] + args.post_steps_settle_seconds if update_ats else baseline_at + args.post_steps_settle_seconds
    if args.quit_command:
        lines.append(f"{quit_at:.2f} text {args.quit_command}")
    return "\n".join(lines) + "\n", baseline_at, update_ats, session_shell


def main() -> int:
    args = parse_args()
    cwd = Path(args.cwd).resolve()
    target_path = (cwd / args.target_file).resolve()

    stdin_script, baseline_at, update_ats, session_shell = build_stdin_script(args, target_path)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", prefix="zide-nvim-repro-", suffix=".stdin", delete=False) as handle:
        handle.write(
            "# Generated by terminal_capture_nvim_real_config_cursor_repro.py\n"
            "# <seconds> <file|text|hex> <payload>\n"
        )
        handle.write(stdin_script)
        stdin_script_path = handle.name

    argv = [
        sys.executable,
        "tools/terminal_capture_redraw_fixture.py",
        "--name",
        args.name,
        "--rows",
        str(args.rows),
        "--cols",
        str(args.cols),
        "--cwd",
        str(cwd),
        "--capture-dir",
        args.capture_dir,
        "--fixture-dir",
        args.fixture_dir,
        "--checkpoint-quiet-ms",
        str(args.checkpoint_quiet_ms),
        "--single-session-shell",
        session_shell,
        "--single-session-stdin-script",
        stdin_script_path,
        "--single-session-baseline-at",
        f"{baseline_at:.2f}",
    ]
    if args.no_stdout:
        argv.append("--no-stdout")
    for update_at in update_ats:
        argv.extend(["--single-session-update-at", f"{update_at:.2f}"])
    if args.hydrate_observed:
        argv.append("--hydrate-observed")
    if args.update_goldens:
        argv.append("--update-goldens")
    if args.validate:
        argv.append("--validate")

    print("running:", " ".join(shlex.quote(part) for part in argv))
    print("stdin-script:", stdin_script_path)
    return subprocess.run(argv, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
